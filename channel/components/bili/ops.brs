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
    else if op = "me" then
        res = opMe()
    else if op = "favfolders" then
        res = opFavFolders()
    else if op = "liveplay" then
        res = opLivePlay(p)
    else if op = "favcovers" then
        res = opFavCovers(p)
    else if op = "favlist" then
        res = opFavList(p)
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
    else if which = "live" then
        return opLiveList(page)
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

' ---------- live ----------

function liveApi() as String
    return "https://api.live.bilibili.com"
end function

' A live room in the shape of a video card, so the same grid can show it.
function liveCard(r as Object, followed as Boolean) as Object
    online = r.online
    if isNil(online) and type(r.watched_show) = "roAssociativeArray" then online = r.watched_show.num
    area = strOf(firstOf([r.area_v2_name, r.areaName, r.area_name]))
    if followed then area = "你关注的"
    return {
        bvid: ""
        roomid: strOf(firstOf([r.roomid, r.room_id]))
        title: fit(stripTags(strOf(r.title)))
        up: fit(strOf(r.uname))
        poster: sized(strOf(firstOf([r.user_cover, r.cover_from_user, r.cover, r.keyframe, r.system_cover])), 480, 300)
        duration: 0
        duration_text: "直播"
        view_text: fmtCount(online)
        stats_text: "人气 " + fmtCount(online)
        date_text: fit(area)
        live: true
        progress: 0
    }
end function

' Page 1 starts with the followed streamers who are live now (when logged in);
' every page then lists the most watched rooms across the site.
function opLiveList(page as Integer) as Object
    items = []
    seen = {}
    if page = 1 and isLoggedIn() then
        r = biliApi(liveApi() + "/xlive/web-ucenter/v1/xfetter/GetWebList", { page: 1, page_size: 30 })
        if r.ok and type(r.data) = "roAssociativeArray" then
            if type(r.data.rooms) = "roArray" then
                for each room in r.data.rooms
                    c = liveCard(room, true)
                    if c.roomid <> "" and not seen.DoesExist(c.roomid) then
                        seen[c.roomid] = true
                        items.Push(c)
                    end if
                end for
            end if
        end if
    end if
    r = biliApi(liveApi() + "/room/v1/Area/getListByAreaID", { areaId: 0, sort: "online", pageSize: 30, page: page })
    if not r.ok then
        if items.Count() > 0 then return okWith({ items: items })
        return fail(r.error)
    end if
    if type(r.data) = "roArray" then
        for each room in r.data
            c = liveCard(room, false)
            if c.roomid <> "" and not seen.DoesExist(c.roomid) then
                seen[c.roomid] = true
                items.Push(c)
            end if
        end for
    end if
    return okWith({ items: items })
end function

' HLS for the room at the asked quality (the server caps it: 原画 needs a login).
' Out: url, headers, current quality and the list a viewer can switch between.
function opLivePlay(p as Object) as Object
    qn = intOf(p.qn)
    if qn <= 0 then qn = 10000
    r = biliApi(liveApi() + "/xlive/web-room/v2/index/getRoomPlayInfo", { room_id: strOf(p.roomid), protocol: 1, format: "1,2", codec: 0, qn: qn, platform: "web" })
    if not r.ok then return fail(r.error)
    d = r.data
    if intOf(d.live_status) <> 1 then return fail("主播现在没有在直播")
    info = d.playurl_info
    if type(info) <> "roAssociativeArray" then return fail("拿不到直播地址")
    pu = info.playurl
    names = {}
    if type(pu.g_qn_desc) = "roArray" then
        for each q in pu.g_qn_desc
            names["q" + intOf(q.qn).ToStr()] = fit(strOf(q.desc))
        end for
    end if
    ' fmp4 when the loopback server can split its audio out; ts otherwise
    byFormat = {}
    for each stream in pu.stream
        if strOf(stream.protocol_name) = "http_hls" then
            for each fmt in stream.format
                for each codec in fmt.codec
                    if strOf(codec.codec_name) = "avc" then byFormat[strOf(fmt.format_name)] = codec
                end for
            end for
        end if
    end for
    best = byFormat["fmp4"]
    splitAudio = best <> invalid and m.global.mpdPort > 0
    if not splitAudio then best = byFormat["ts"]
    if best = invalid then return fail("这个直播间没有电视能播的格式")
    host = best.url_info[0]
    url = strOf(host.host) + strOf(best.base_url) + strOf(host.extra)
    current = intOf(best.current_qn)
    qualities = []
    for each a in best.accept_qn
        n = names["q" + intOf(a).ToStr()]
        if isNil(n) then n = intOf(a).ToStr()
        qualities.Push({ qn: intOf(a), name: n })
    end for
    cur = names["q" + current.ToStr()]
    if isNil(cur) then cur = ""
    out = { url: url, headers: liveHeaders(), qn: current, quality_name: cur, qualities: qualities, sid: "" }
    if splitAudio then splitLiveAudio(out, strOf(p.roomid))
    return okWith(out)
end function

' Roku plays Bilibili's muxed fmp4 without sound. Point the player at a master
' playlist on the loopback server instead: video straight from the CDN, audio
' as its own rendition that the server cuts out of the same segments.
sub splitLiveAudio(out as Object, roomid as String)
    src = out.url
    codecs = "avc1.640028"
    pl = httpGet(src, false, 6000)
    if pl.code = 200 and liveMapOf(pl.body) <> "" then
        init = liveFetchBytes(liveBaseOf(src) + liveMapOf(pl.body), out.headers, 6000, "tmp:/live_task_init.m4s")
        if init <> invalid then codecs = rokuCodecs(mp4AvcCodec(init))   ' 原画 says level 5.0, which Roku turns down
    end if
    sid = "live" + roomid + "_" + CreateObject("roDateTime").AsSeconds().ToStr()
    q = Chr(34)
    lf = Chr(10)
    master = "#EXTM3U" + lf + "#EXT-X-VERSION:7" + lf + "#EXT-X-INDEPENDENT-SEGMENTS" + lf
    master = master + "#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID=" + q + "aud" + q + ",NAME=" + q + "audio" + q + ",DEFAULT=YES,AUTOSELECT=YES,URI=" + q + sid + "/a.m3u8" + q + lf
    master = master + "#EXT-X-STREAM-INF:BANDWIDTH=6000000,CODECS=" + q + codecs + ",mp4a.40.2" + q + ",AUDIO=" + q + "aud" + q + lf
    master = master + src + lf
    out.sid = sid
    out.src = src
    out.base = liveBaseOf(src)
    out.manifest = master
    out.url = "http://127.0.0.1:" + m.global.mpdPort.ToStr() + "/" + sid + ".m3u8"
end sub

' ---------- 我的: account card and favourites ----------

' Name, avatar, level, membership and the follow / fan / coin counts.
function opMe() as Object
    r = biliApi(apiBase() + "/x/web-interface/nav", {})
    if not r.ok then return fail(r.error)
    d = r.data
    lv = 0
    if type(d.level_info) = "roAssociativeArray" then lv = intOf(d.level_info.current_level)
    vip = ""
    if type(d.vip_label) = "roAssociativeArray" then vip = strOf(d.vip_label.text)
    if vip = "" and type(d.vip) = "roAssociativeArray" then
        if type(d.vip.label) = "roAssociativeArray" then vip = strOf(d.vip.label.text)
    end if
    coins = 0# + 0
    if not isNil(d.money) then coins = 0# + d.money
    st = {}
    s = biliApi(apiBase() + "/x/web-interface/nav/stat", {})
    if s.ok and type(s.data) = "roAssociativeArray" then st = s.data
    return okWith({
        uname: fit(strOf(d.uname))
        face: sized(strOf(d.face), 160, 160)
        level: lv
        vip: fit(vip)
        coins: oneDecimalTrim(coins)
        following: fmtCount(st.following)
        follower: fmtCount(st.follower)
    })
end function

function oneDecimalTrim(x as Double) as String
    if x = Int(x) then return Int(x).ToStr()
    return oneDecimal(x)
end function

' The account's own folders (默认收藏夹 first) with cover and size.
function opFavFolders() as Object
    uid = strOf(loadCookies().dedeuserid)
    if uid = "" then return fail("未登录")
    out = []
    page = 1
    while page <= 5
        r = biliApi(apiBase() + "/x/v3/fav/folder/created/list", { up_mid: uid, pn: page, ps: 50 })
        if not r.ok then return fail(r.error)
        if type(r.data) <> "roAssociativeArray" then exit while
        if type(r.data.list) = "roArray" then
            for each f in r.data.list
                title = fit(strOf(f.title))
                if title = "" then title = "未命名收藏夹"   ' an all-emoji name has nothing left to draw
                out.Push({ id: strOf(f.id), title: title, count: intOf(f.media_count), cover: sized(strOf(f.cover), 480, 300) })
            end for
        end if
        if not boolOf(r.data.has_more) then exit while
        page = page + 1
    end while
    return okWith({ folders: out })
end function

' Most folders come back without a cover; use each one's newest video instead.
' p.ids: folder ids -> { covers: { <id>: url } }
function opFavCovers(p as Object) as Object
    covers = {}
    if type(p.ids) <> "roArray" then return okWith({ covers: covers })
    for each id in p.ids
        r = biliApi(apiBase() + "/x/v3/fav/resource/list", { media_id: strOf(id), pn: 1, ps: 1, order: "mtime", type: 0, tid: 0, platform: "web" })
        if r.ok and type(r.data) = "roAssociativeArray" then
            if type(r.data.medias) = "roArray" then
                if r.data.medias.Count() > 0 then covers[strOf(id)] = sized(strOf(r.data.medias[0].cover), 480, 300)
            end if
        end if
    end for
    return okWith({ covers: covers })
end function

' One page of a folder, newest favourite first; removed videos are skipped.
function opFavList(p as Object) as Object
    page = intOf(p.page)
    if page < 1 then page = 1
    r = biliApi(apiBase() + "/x/v3/fav/resource/list", { media_id: strOf(p.id), pn: page, ps: 20, order: "mtime", type: 0, tid: 0, platform: "web" })
    if not r.ok then return fail(r.error)
    items = []
    more = false
    if type(r.data) = "roAssociativeArray" then
        more = boolOf(r.data.has_more)
        if type(r.data.medias) = "roArray" then
            for each v in r.data.medias
                if intOf(v.type) = 2 and strOf(v.bvid) <> "" and strOf(v.title) <> "已失效视频" then
                    v.aid = v.id
                    items.Push(card(v))
                end if
            end for
        end if
    end if
    return okWith({ items: items, last: not more })
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
