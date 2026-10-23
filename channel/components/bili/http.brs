' Bilibili web API plumbing for Task threads: cookies, WBI signing, JSON.
' Everything here runs inside BiliTask/other Task nodes (roUrlTransfer is not
' allowed on the render thread).

function biliUA() as String
    return "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
end function

' Headers the video CDN insists on; the player sends these with every segment.
function mediaHeaders() as Object
    return ["Referer: https://www.bilibili.com/", "User-Agent: " + biliUA()]
end function

' ---------- cookies (registry, lower-cased names -> values) ----------

function cookieNames() as Object
    return ["buvid3", "buvid4", "b_nut", "SESSDATA", "bili_jct", "DedeUserID", "DedeUserID__ckMd5"]
end function

function loadCookies() as Object
    sec = CreateObject("roRegistrySection", "bili")
    if sec.Exists("cookies") then
        c = ParseJson(sec.Read("cookies"))
        if type(c) = "roAssociativeArray" then return c
    end if
    return {}
end function

sub saveCookies(c as Object)
    sec = CreateObject("roRegistrySection", "bili")
    sec.Write("cookies", FormatJson(c))
    sec.Flush()
end sub

function cookieHeader(c as Object) as String
    parts = []
    for each name in cookieNames()
        v = c[LCase(name)]
        if not isNil(v) then
            if v <> "" then parts.Push(name + "=" + v)
        end if
    end for
    return parts.Join("; ")
end function

function isLoggedIn() as Boolean
    v = loadCookies().sessdata
    if isNil(v) then return false
    return v <> ""
end function

' The API gate wants buvid cookies before signed calls; mint them once and keep them.
sub ensureBuvid()
    c = loadCookies()
    if not isNil(c.buvid3) then return
    r = httpGet("https://api.bilibili.com/x/frontend/finger/spi", false)
    j = invalid
    if r.code = 200 then j = ParseJson(r.body)
    if type(j) <> "roAssociativeArray" then return
    if type(j.data) <> "roAssociativeArray" then return
    c.buvid3 = strOf(j.data.b_3)
    c.buvid4 = esc(strOf(j.data.b_4))
    c.b_nut = CreateObject("roDateTime").AsSeconds().ToStr()
    saveCookies(c)
end sub

' ---------- HTTP ----------

function esc(s as String) as String
    if m.escaper = invalid then m.escaper = CreateObject("roUrlTransfer")
    return m.escaper.Escape(s)
end function

' GET with browser-like headers; returns { code, body, failure, headers }.
' headers is roUrlEvent's array form, one {name: value} per header, so repeated
' Set-Cookie lines survive.
function httpGet(url as String, withCookies = true as Boolean) as Object
    return httpRequest(url, invalid, withCookies)
end function

' Form POST (application/x-www-form-urlencoded), same headers and result as httpGet.
function httpPost(url as String, form as String) as Object
    return httpRequest(url, form, true)
end function

function httpRequest(url as String, form as Dynamic, withCookies as Boolean) as Object
    port = CreateObject("roMessagePort")
    x = CreateObject("roUrlTransfer")
    x.SetMessagePort(port)
    x.SetUrl(url)
    x.SetCertificatesFile("common:/certs/ca-bundle.crt")
    x.InitClientCertificates()
    x.EnableEncodings(true)
    x.RetainBodyOnError(true)
    x.AddHeader("User-Agent", biliUA())
    x.AddHeader("Referer", "https://www.bilibili.com/")
    x.AddHeader("Origin", "https://www.bilibili.com")
    x.AddHeader("Accept-Language", "zh-CN,zh;q=0.9")
    if withCookies then
        ck = cookieHeader(loadCookies())
        if ck <> "" then x.AddHeader("Cookie", ck)
    end if
    out = { code: 0, body: "", failure: "", headers: [] }
    if isNil(form) then
        sent = x.AsyncGetToString()
    else
        x.AddHeader("Content-Type", "application/x-www-form-urlencoded")
        sent = x.AsyncPostFromString(form)
    end if
    if not sent then
        out.failure = "request not sent"
        return out
    end if
    msg = wait(20000, port)
    if type(msg) = "roUrlEvent" then
        out.code = msg.GetResponseCode()
        out.body = msg.GetString()
        out.failure = msg.GetFailureReason()
        out.headers = msg.GetResponseHeadersArray()
    else
        x.AsyncCancel()
        out.failure = "timeout"
    end if
    return out
end function

' ids such as cid/aid overflow 32 bits; quote them before ParseJson can round them.
function parseBili(body as String) as Dynamic
    if Len(body) = 0 then return invalid
    if m.bigInts = invalid then m.bigInts = CreateObject("roRegex", """(aid|cid|oid|mid|id|season_id|ep_id|rpid|last_play_cid|max)"":(\d{9,})", "")
    return ParseJson(m.bigInts.ReplaceAll(body, """\1"":""\2"""))
end function

' ---------- WBI signing ----------

function md5Hex(s as String) as String
    ba = CreateObject("roByteArray")
    ba.FromAsciiString(s)
    d = CreateObject("roEVPDigest")
    d.Setup("md5")
    return d.Process(ba)
end function

function wbiKeyFromUrl(url as String) as String
    name = url.Tokenize("/").GetTail()
    return name.Tokenize(".").GetHead()
end function

function mixinKey() as String
    now = CreateObject("roDateTime").AsSeconds()
    g = m.global
    if g.wbiKey <> "" and now - g.wbiAt < 3600 then return g.wbiKey
    r = httpGet("https://api.bilibili.com/x/web-interface/nav")
    j = parseBili(r.body)
    if type(j) <> "roAssociativeArray" then return ""
    if type(j.data) <> "roAssociativeArray" then return ""
    img = j.data.wbi_img
    if type(img) <> "roAssociativeArray" then return ""
    raw = wbiKeyFromUrl(img.img_url) + wbiKeyFromUrl(img.sub_url)
    order = [46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, 37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52]
    key = ""
    for i = 0 to 31
        key = key + Mid(raw, order[i] + 1, 1)
    end for
    g.wbiKey = key
    g.wbiAt = now
    return key
end function

function plainQuery(params as Object) as String
    parts = []
    for each k in params
        parts.Push(k + "=" + esc(strOf(params[k])))
    end for
    return parts.Join("&")
end function

function signedQuery(params as Object) as String
    p = {}
    for each k in params
        p[k] = params[k]
    end for
    p.wts = CreateObject("roDateTime").AsSeconds()
    parts = []
    for each k in p.Keys()   ' Keys() comes back sorted
        v = strOf(p[k])
        for each bad in ["!", "'", "(", ")", "*"]
            v = v.Replace(bad, "")
        end for
        parts.Push(k + "=" + esc(v))
    end for
    q = parts.Join("&")
    return q + "&w_rid=" + md5Hex(q + mixinKey())
end function

' Call an api.bilibili.com style endpoint ({code, message, data}).
function biliApi(url as String, params as Object, wbi = false as Boolean) as Object
    ensureBuvid()
    q = ""
    if wbi then
        q = signedQuery(params)
    else
        q = plainQuery(params)
    end if
    full = url
    if q <> "" then full = url + "?" + q
    r = httpGet(full)
    res = { ok: false, data: invalid, error: "", code: 0, headers: r.headers }
    if r.code <= 0 then
        res.error = "网络错误：" + r.failure
        return res
    end if
    j = parseBili(r.body)
    if type(j) <> "roAssociativeArray" then
        res.error = "HTTP " + r.code.ToStr()
        return res
    end if
    res.code = intOf(j.code)
    if res.code <> 0 then
        res.error = strOf(j.message) + "（" + res.code.ToStr() + "）"
        return res
    end if
    res.ok = true
    res.data = j.data
    return res
end function
