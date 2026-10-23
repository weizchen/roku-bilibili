' BiliTask entry point: one operation per task run.

sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    op = m.top.op
    p = m.top.params
    if op = "home" then
        res = opHome(p)
    else if op = "search" then
        res = opSearch(p)
    else if op = "suggest" then
        res = opSuggest(p)
    else if op = "hotsearch" then
        res = opHotSearch()
    else if op = "video" then
        res = opVideo(p)
    else if op = "related" then
        res = opRelated(p)
    else if op = "play" then
        res = opPlay(p)
    else if op = "danmaku" then
        res = opDanmaku(p)
    else if op = "nav" then
        res = opNav()
    else if op = "qr" then
        res = opQr()
    else if op = "qrpoll" then
        res = opQrPoll(p)
    else if op = "logout" then
        res = opLogout()
    else if op = "report" then
        res = opReport(p)
    else if op = "progress" then
        res = opProgress(p)
    else if op = "historydelete" then
        res = opHistoryDelete(p)
    else if op = "historyclear" then
        res = opHistoryClear()
    else
        res = fail("unknown op " + op)
    end if
    m.top.response = res
end sub

function okWith(data as Object) as Object
    return { ok: true, data: data, error: "" }
end function

function fail(msg as String) as Object
    return { ok: false, data: invalid, error: msg }
end function

function apiBase() as String
    return "https://api.bilibili.com"
end function

' ---------- lists ----------

function opHome(p as Object) as Object
    which = strOf(p.tab)
    page = intOf(p.page)
    if page < 1 then page = 1
    if which = "popular" then
        r = biliApi(apiBase() + "/x/web-interface/popular", { ps: 20, pn: page })
        if not r.ok then return fail(r.error)
        return okWith({ items: cardsOf(r.data.list) })
    else if which = "rank" then
        r = biliApi(apiBase() + "/x/web-interface/ranking/v2", { rid: 0, type: "all" })
        if not r.ok then return fail(r.error)
        return okWith({ items: cardsOf(r.data.list) })
    else if which = "history" then
        ' paged by cursor: pass back the max / view_at / business of the previous page
        q = { ps: 30, type: "archive" }
        if strOf(p.max) <> "" then
            q.max = strOf(p.max)
            q.view_at = strOf(p.view_at)
            q.business = strOf(p.business)
        end if
        r = biliApi(apiBase() + "/x/web-interface/history/cursor", q)
        if not r.ok then return fail(r.error)
        items = []
        if type(r.data.list) = "roArray" then
            for each v in r.data.list
                h = v.history
                if type(h) = "roAssociativeArray" then
                    if strOf(h.bvid) <> "" and (isNil(h.business) or strOf(h.business) = "archive") then
                        v.bvid = h.bvid
                        v.cid = h.cid
                        v.aid = h.oid
                        v.author = v.author_name
                        c = card(v)
                        ' history has no play counts; show how far you got instead (-1 = finished)
                        c.progress = intOf(v.progress)
                        if c.progress < 0 then
                            c.progress = c.duration
                            c.view_text = "已看完"
                        else if c.progress > 0 then
                            c.view_text = "看到 " + fmtTime(c.progress)
                        else
                            c.view_text = ""
                        end if
                        c.history = true
                        items.Push(c)
                    end if
                end if
            end for
        end if
        cur = r.data.cursor
        if type(cur) <> "roAssociativeArray" then cur = {}
        raw = 0
        if type(r.data.list) = "roArray" then raw = r.data.list.Count()
        return okWith({ items: items, cursor: { max: strOf(cur.max), view_at: strOf(cur.view_at), business: strOf(cur.business) }, last: raw = 0 or strOf(cur.max) = "0" or strOf(cur.max) = "" })
    end if
    ' personalised once logged in, generic otherwise
    r = biliApi(apiBase() + "/x/web-interface/wbi/index/top/feed/rcmd", { ps: 20, fresh_type: 4, feed_version: "V8", fresh_idx: page, fresh_idx_1h: page, brush: page, homepage_ver: 1, web_location: 1430650 }, true)
    if r.ok then return okWith({ items: cardsOf(r.data.item) })
    r = biliApi(apiBase() + "/x/web-interface/popular", { ps: 20, pn: page })
    if not r.ok then return fail(r.error)
    return okWith({ items: cardsOf(r.data.list) })
end function

function opSearch(p as Object) as Object
    page = intOf(p.page)
    if page < 1 then page = 1
    r = biliApi(apiBase() + "/x/web-interface/wbi/search/type", { search_type: "video", keyword: strOf(p.q), page: page, page_size: 30, web_location: 1430654 }, true)
    if not r.ok then return fail(r.error)
    return okWith({ q: strOf(p.q), items: cardsOf(r.data.result) })
end function

function opSuggest(p as Object) as Object
    r = httpGet("https://s.search.bilibili.com/main/suggest?term=" + esc(strOf(p.q)) + "&main_ver=v1&func=suggest")
    out = []
    j = parseBili(r.body)
    if type(j) = "roAssociativeArray" then
        if type(j.result) = "roAssociativeArray" then
            if type(j.result.tag) = "roArray" then
                for each t in j.result.tag
                    w = fit(strOf(t.value))
                    if w <> "" then out.Push(w)
                end for
            end if
        end if
    end if
    return okWith({ items: out })
end function

function opHotSearch() as Object
    r = biliApi(apiBase() + "/x/web-interface/search/square", { limit: 10 })
    out = []
    if r.ok then
        tr = r.data.trending
        if type(tr) = "roAssociativeArray" then
            if type(tr.list) = "roArray" then
                for each t in tr.list
                    w = fit(strOf(firstOf([t.show_name, t.keyword])))
                    if w <> "" then out.Push(w)
                end for
            end if
        end if
    end if
    return okWith({ items: out })
end function

' ---------- one video ----------

function opVideo(p as Object) as Object
    r = biliApi(apiBase() + "/x/web-interface/wbi/view", { bvid: strOf(p.bvid) }, true)
    if not r.ok then return fail(r.error)
    d = r.data
    owner = d.owner
    if type(owner) <> "roAssociativeArray" then owner = {}
    stat = d.stat
    if type(stat) <> "roAssociativeArray" then stat = {}
    pages = []
    if type(d.pages) = "roArray" then
        for each pg in d.pages
            part = fit(strOf(pg.part))
            if part = "" then part = "P" + strOf(pg.page)
            pages.Push({ cid: strOf(pg.cid), page: intOf(pg.page), part: part, duration: intOf(pg.duration), duration_text: fmtTime(intOf(pg.duration)) })
        end for
    end if
    desc = strOf(d.desc)
    if Len(desc) > 400 then desc = Left(desc, 400) + "…"
    return okWith({
        bvid: strOf(d.bvid)
        aid: strOf(d.aid)
        cid: strOf(d.cid)
        title: fit(strOf(d.title))
        desc: fit(desc)
        up: fit(strOf(owner.name))
        poster: sized(strOf(d.pic), 640, 400)
        duration: intOf(d.duration)
        date_text: dateText(intOf(d.pubdate))
        ago_text: ago(intOf(d.pubdate))
        view_text: fmtCount(stat.view)
        danmaku_text: fmtCount(stat.danmaku)
        like_text: fmtCount(stat.like)
        pages: pages
    })
end function

function opRelated(p as Object) as Object
    r = biliApi(apiBase() + "/x/web-interface/archive/related", { bvid: strOf(p.bvid) })
    if not r.ok then return fail(r.error)
    return okWith({ items: cardsOf(r.data, 20) })
end function

' Logged out, DASH tops out at 480P while the progressive MP4 still gets 720P,
' so DASH is only worth it with a session (1080P).
function opPlay(p as Object) as Object
    fmt = strOf(p.fmt)
    if fmt = "" or fmt = "auto" then
        if isLoggedIn() and m.global.mpdPort > 0 then
            fmt = "dash"
        else
            fmt = "mp4"
        end if
    end if
    if fmt = "dash" and m.global.mpdPort <= 0 then fmt = "mp4"
    bvid = strOf(p.bvid)
    cid = strOf(p.cid)

    if fmt = "mp4" then
        r = biliApi(apiBase() + "/x/player/wbi/playurl", { bvid: bvid, cid: cid, qn: 64, fnval: 1, fnver: 0, fourk: 1, platform: "pc", high_quality: 1 }, true)
        if not r.ok then return fail(r.error)
        durl = r.data.durl
        if type(durl) <> "roArray" then return fail("这个视频没有 MP4 版本")
        if durl.Count() = 0 then return fail("这个视频没有 MP4 版本")
        q = intOf(r.data.quality)
        return okWith({ format: "mp4", url: strOf(durl[0].url), headers: mediaHeaders(), quality: q, quality_name: qualityName(q, 0) })
    end if

    r = biliApi(apiBase() + "/x/player/wbi/playurl", { bvid: bvid, cid: cid, qn: 80, fnval: 4048, fnver: 0, fourk: 1, platform: "pc", high_quality: 1 }, true)
    if not r.ok then return fail(r.error)
    dash = r.data.dash
    if type(dash) <> "roAssociativeArray" then return fail("这个视频没有 DASH 版本")
    tracks = selectTracks(dash)
    if tracks = invalid then return fail("没有电视能播放的码流")
    top = tracks.videos[tracks.videos.Count() - 1]
    duration = intOf(dash.duration)
    if duration <= 0 then duration = intOf(r.data.timelength) \ 1000
    sid = bvid + "-" + cid + "-" + CreateObject("roDateTime").AsSeconds().ToStr()
    return okWith({
        format: "dash"
        sid: sid
        mpd: buildMpd(tracks, duration)
        url: "http://127.0.0.1:" + m.global.mpdPort.ToStr() + "/" + sid + ".mpd"
        headers: mediaHeaders()
        quality: top.qid
        quality_name: qualityName(top.qid, top.height)
    })
end function

' ---------- watch progress on the account ----------

' Same call the web player makes, so TV viewing shows up in the account's history
' (and on the phone). progress is in seconds.
function opReport(p as Object) as Object
    return accountPost("/x/v2/history/report", { aid: strOf(p.aid), cid: strOf(p.cid), progress: intOf(p.progress) })
end function

' kid names the record: archive_<aid> for ordinary videos
function opHistoryDelete(p as Object) as Object
    return accountPost("/x/v2/history/delete", { kid: "archive_" + strOf(p.aid) })
end function

function opHistoryClear() as Object
    return accountPost("/x/v2/history/clear", {})
end function

' Form POST on behalf of the logged-in account; bili_jct doubles as the csrf token.
function accountPost(path as String, params as Object) as Object
    c = loadCookies()
    if isNil(c.sessdata) or isNil(c.bili_jct) then return fail("未登录")
    params.csrf = strOf(c.bili_jct)
    r = httpPost(apiBase() + path, plainQuery(params))
    j = parseBili(r.body)
    if type(j) <> "roAssociativeArray" then return fail("请求失败（HTTP " + r.code.ToStr() + "）")
    if intOf(j.code) <> 0 then return fail(strOf(j.message) + "（" + strOf(j.code) + "）")
    return okWith({})
end function

' Where the account left off: last_play_time is in ms, last_play_cid picks the part.
function opProgress(p as Object) as Object
    r = biliApi(apiBase() + "/x/player/wbi/v2", { aid: strOf(p.aid), cid: strOf(p.cid) }, true)
    if not r.ok then return fail(r.error)
    return okWith({ bvid: strOf(p.bvid), cid: strOf(r.data.last_play_cid), seconds: intOf(r.data.last_play_time) \ 1000 })
end function

' ---------- danmaku ----------

function hexColor(c as Integer) as String
    h = UCase(StrI(c, 16))
    while Len(h) < 6
        h = "0" + h
    end while
    return "0x" + h + "FF"
end function

' The legacy XML endpoint: one deflate-encoded file (roUrlTransfer inflates it).
' Out: items as [time, mode, color, text], sorted, at most 12 per second.
function opDanmaku(p as Object) as Object
    r = httpGet("https://comment.bilibili.com/" + strOf(p.cid) + ".xml")
    if r.code <> 200 then return fail("弹幕加载失败（" + r.code.ToStr() + "）")
    xml = CreateObject("roXMLElement")
    if not xml.Parse(r.body) then return fail("弹幕解析失败")
    raw = []
    for each d in xml.GetNamedElements("d")
        attrs = d.GetAttributes()
        parts = strOf(attrs.p).Split(",")
        if parts.Count() >= 4 then
            mode = parts[1].ToInt()
            if mode = 1 or mode = 4 or mode = 5 then
                text = fit(d.GetText())
                if Len(text) > 40 then text = Left(text, 40)
                if text <> "" then raw.Push({ t: Val(parts[0]), m: mode, c: parts[3].ToInt(), s: text })
            end if
        end if
    end for
    raw.SortBy("t")
    items = []
    bucket = -1
    inBucket = 0
    for each e in raw
        b = Int(e.t)
        if b <> bucket then
            bucket = b
            inBucket = 0
        end if
        if inBucket < 12 then
            items.Push([e.t, e.m, hexColor(e.c), e.s])
            inBucket = inBucket + 1
        end if
    end for
    return okWith({ cid: strOf(p.cid), items: items, total: raw.Count() })
end function

' ---------- account ----------

function opNav() as Object
    had = isLoggedIn()
    r = biliApi(apiBase() + "/x/web-interface/nav", {})
    if r.code = -101 or (r.ok and r.data.isLogin = false) then
        if had then opLogout()
        return okWith({ logged_in: false })
    end if
    if not r.ok then return fail(r.error)
    return okWith({ logged_in: r.data.isLogin = true, uname: fit(strOf(r.data.uname)) })
end function

function opQr() as Object
    ensureBuvid()
    r = biliApi("https://passport.bilibili.com/x/passport-login/web/qrcode/generate", { source: "main-fe-header" })
    if not r.ok then return fail(r.error)
    qr = qrEncode(strOf(r.data.url))
    if qr = invalid then return fail("二维码太长")
    return okWith({ key: strOf(r.data.qrcode_key), size: qr.size, rows: qr.rows, version: qr.version, mask: qr.mask })
end function

function isSessionCookie(name as String) as Boolean
    return name = "sessdata" or name = "bili_jct" or name = "dedeuserid" or name = "dedeuserid__ckmd5"
end function

' Success hands the session back as Set-Cookie headers and, on older servers, also
' in data.url's query string. Take it from whichever carries it.
function opQrPoll(p as Object) as Object
    r = biliApi("https://passport.bilibili.com/x/passport-login/web/qrcode/poll", { qrcode_key: strOf(p.key), source: "main-fe-header" })
    if not r.ok then return fail(r.error)
    code = intOf(r.data.code)
    status = "waiting"
    if code = 86090 then status = "scanned"
    if code = 86038 then status = "expired"
    if code <> 0 then return okWith({ status: status, code: code })

    c = loadCookies()
    fromHeaders = []
    fromUrl = []
    for each h in r.headers
        for each k in h
            if LCase(k) = "set-cookie" then
                parts = strOf(h[k]).Split(";")
                pair = parts[0]
                eq = Instr(1, pair, "=")
                if eq > 1 then
                    name = Left(pair, eq - 1)
                    name = LCase(name.Trim())
                    if isSessionCookie(name) then
                        c[name] = Mid(pair, eq + 1)
                        fromHeaders.Push(name)
                    end if
                end if
            end if
        end for
    end for
    url = strOf(r.data.url)
    qs = Instr(1, url, "?")
    if qs > 0 then
        for each item in Mid(url, qs + 1).Split("&")
            eq = Instr(1, item, "=")
            if eq > 1 then
                name = LCase(Left(item, eq - 1))
                if isSessionCookie(name) then
                    c[name] = Mid(item, eq + 1)
                    fromUrl.Push(name)
                end if
            end if
        end for
    end if
    ' names only, never values
    print "[login] confirmed; cookies from headers: "; fromHeaders.Join(","); " | from url: "; fromUrl.Join(","); " | headers seen: "; r.headers.Count()
    if isNil(c.sessdata) then
        return okWith({ status: "failed", code: code, message: "手机已确认，但没收到登录凭证（响应头 " + r.headers.Count().ToStr() + " 个，链接参数 " + fromUrl.Count().ToStr() + " 个）" })
    end if
    saveCookies(c)
    return okWith({ status: "ok", code: code })
end function

function opLogout() as Object
    c = loadCookies()
    for each name in ["sessdata", "bili_jct", "dedeuserid", "dedeuserid__ckmd5"]
        c.Delete(name)
    end for
    saveCookies(c)
    return okWith({ logged_in: false })
end function
