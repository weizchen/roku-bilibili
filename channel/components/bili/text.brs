' Shaping bilibili payloads into what the screens show.

' Drop characters the bundled CJK font has no glyph for (emoji etc.), using the
' coverage bitmap make-font.py writes next to the font. Roku would draw boxes.
function fit(s as String) as String
    n = Len(s)
    if n = 0 then return s
    if m.cov = invalid then
        m.cov = CreateObject("roByteArray")
        if not m.cov.ReadFile("pkg:/fonts/cjk.cov") then m.cov = CreateObject("roByteArray")
    end if
    cov = m.cov
    if cov.Count() = 0 then return s
    bits = [1, 2, 4, 8, 16, 32, 64, 128]
    out = ""
    for i = 1 to n
        ch = Mid(s, i, 1)
        c = Asc(ch)
        if c = 10 then
            out = out + ch
        else if c > 0 and c < 65536 then
            if (cov[c \ 8] and bits[c mod 8]) <> 0 then out = out + ch
        end if
    end for
    while Instr(1, out, "  ") > 0
        out = out.Replace("  ", " ")
    end while
    return out.Trim()
end function

function stripTags(s as String) as String
    if Instr(1, s, "<") = 0 and Instr(1, s, "&") = 0 then return s
    if m.tags = invalid then m.tags = CreateObject("roRegex", "<[^>]*>", "")
    s = m.tags.ReplaceAll(s, "")
    s = s.Replace("&quot;", Chr(34)).Replace("&#39;", "'").Replace("&lt;", "<").Replace("&gt;", ">").Replace("&amp;", "&")
    return s
end function

function fmtCount(v as Dynamic) as String
    if isNil(v) then return "0"
    if type(v) = "String" or type(v) = "roString" then return v
    n = 0# + v
    if n >= 100000000 then return oneDecimal(n / 100000000) + "亿"
    if n >= 10000 then return oneDecimal(n / 10000) + "万"
    return Int(n).ToStr()
end function

function oneDecimal(x as Double) as String
    t = Int(x * 10 + 0.5)
    return (t \ 10).ToStr() + "." + (t mod 10).ToStr()
end function

function twoDigits(n as Integer) as String
    if n < 10 then return "0" + n.ToStr()
    return n.ToStr()
end function

' unix seconds -> "2026-10-18" (or "10-18" within the current year when short)
function dateText(ts as Integer, short = false as Boolean) as String
    if ts <= 0 then return ""
    dt = CreateObject("roDateTime")
    dt.FromSeconds(ts)
    dt.ToLocalTime()
    md = twoDigits(dt.GetMonth()) + "-" + twoDigits(dt.GetDayOfMonth())
    if short then
        today = CreateObject("roDateTime")
        today.ToLocalTime()
        if today.GetYear() = dt.GetYear() then return md
    end if
    return dt.GetYear().ToStr() + "-" + md
end function

' unix seconds -> "刚刚" / "5分钟前" / "3小时前" / "昨天" / "12天前" / "08-14" / "2024-08-14"
function ago(ts as Integer) as String
    if ts <= 0 then return ""
    d = CreateObject("roDateTime").AsSeconds() - ts
    if d < 60 then return "刚刚"
    if d < 3600 then return (d \ 60).ToStr() + "分钟前"
    if d < 86400 then return (d \ 3600).ToStr() + "小时前"
    if d < 2 * 86400 then return "昨天"
    if d < 30 * 86400 then return (d \ 86400).ToStr() + "天前"
    return dateText(ts, true)
end function

' "12:34" / "1:02:03" / seconds / milliseconds -> seconds
function secondsOf(v as Dynamic) as Integer
    if isNil(v) then return 0
    t = type(v)
    if t = "String" or t = "roString" then
        total = 0
        for each part in v.Split(":")
            total = total * 60 + part.ToInt()
        end for
        return total
    end if
    n = intOf(v)
    if n > 100000 then n = n \ 1000
    return n
end function

' interactive videos report 0 seconds; show no badge rather than "0:00"
function durationBadge(sec as Integer) as String
    if sec <= 0 then return ""
    return fmtTime(sec)
end function

function httpsPic(pic as String) as String
    if Left(pic, 2) = "//" then return "https:" + pic
    if Left(pic, 5) = "http:" then return "https:" + Mid(pic, 6)
    return pic
end function

' bilibili's image service resizes for us; keeps the old TV's memory in check
function sized(pic as String, w as Integer, h as Integer) as String
    if pic = "" then return ""
    return httpsPic(pic) + "@" + w.ToStr() + "w_" + h.ToStr() + "h_1c.jpg"
end function

function firstOf(a as Object) as Dynamic
    for each v in a
        if not isNil(v) then
            if strOf(v) <> "" and strOf(v) <> "0" then return v
        end if
    end for
    return invalid
end function

' Normalise the many shapes bilibili uses for a video card into one.
function card(v as Object) as Object
    owner = v.owner
    if type(owner) <> "roAssociativeArray" then owner = {}
    stat = v.stat
    if type(stat) <> "roAssociativeArray" then stat = {}
    pic = strOf(firstOf([v.pic, v.cover, v.first_frame]))
    dur = secondsOf(v.duration)
    published = intOf(firstOf([v.pubdate, v.ctime, v.senddate]))
    return {
        bvid: strOf(v.bvid)
        aid: strOf(firstOf([v.aid, v.id]))
        cid: strOf(v.cid)
        title: fit(stripTags(strOf(v.title)))
        up: fit(strOf(firstOf([owner.name, v.author, v.owner_name])))
        poster: sized(pic, 480, 300)
        duration: dur
        duration_text: durationBadge(dur)
        view_text: fmtCount(firstOf([stat.view, v.play]))
        date_text: ago(published)
        progress: 0
    }
end function

function cardsOf(list as Dynamic, limit = 100 as Integer) as Object
    out = []
    if type(list) <> "roArray" then return out
    for each v in list
        if type(v) = "roAssociativeArray" then
            if strOf(v.bvid) <> "" then out.Push(card(v))
        end if
        if out.Count() >= limit then exit for
    end for
    return out
end function
