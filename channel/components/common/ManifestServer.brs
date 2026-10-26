sub init()
    m.top.functionName = "serve"
end sub

sub serve()
    port = CreateObject("roMessagePort")
    server = invalid
    for p = 8899 to 8909
        addr = CreateObject("roSocketAddress")
        addr.SetHostName("127.0.0.1")
        addr.SetPort(p)
        s = CreateObject("roStreamSocket")
        s.SetMessagePort(port)
        s.SetAddress(addr)
        s.NotifyReadable(true)
        if s.Listen(4) then
            server = s
            m.global.mpdPort = p
            exit for
        end if
        s.Close()
    end for
    if server = invalid then
        print "[mpd] no free port, DASH disabled"
        return
    end if

    crlf = Chr(13) + Chr(10)
    clients = {}
    while true
        msg = wait(0, port)
        if type(msg) = "roSocketEvent" then
            id = msg.GetSocketID()
            if id = server.GetID() then
                c = server.Accept()
                if c <> invalid then
                    c.SetMessagePort(port)
                    c.NotifyReadable(true)
                    clients[c.GetID().ToStr()] = c
                end if
            else
                key = id.ToStr()
                c = clients[key]
                if c <> invalid then
                    res = respond(requestPath(c.ReceiveStr(8192)))
                    if res = invalid then res = { status: "404 Not Found", mime: "text/plain", text: "" }
                    if res.bytes <> invalid then res.pieces = { pieces: [{ b: res.bytes, s: 0, n: res.bytes.Count() }], length: res.bytes.Count() }
                    if res.pieces = invalid then
                        length = Len(res.text)
                    else
                        length = res.pieces.length
                    end if
                    head = "HTTP/1.1 " + res.status + crlf + "Content-Type: " + res.mime + crlf + "Content-Length: " + length.ToStr() + crlf + "Cache-Control: no-store" + crlf + "Connection: close" + crlf + crlf
                    if res.pieces = invalid then
                        sendAll(c, head + res.text)
                    else
                        sendAll(c, head)
                        for each piece in res.pieces.pieces
                            sendBytes(c, piece.b, piece.s, piece.n)
                        end for
                    end if
                    c.Close()
                    clients.Delete(key)
                end if
            end if
        end if
    end while
end sub

' "GET /x/y.m3u8 HTTP/1.1 ..." -> "/x/y.m3u8"
function requestPath(req as String) as String
    if Left(req, 4) <> "GET " then return ""
    finish = Instr(5, req, " ")
    if finish = 0 then return ""
    return Mid(req, 5, finish - 5)
end function

function respond(path as String) as Dynamic
    wanted = m.global.mpdId
    if wanted = "" or path = "" then return invalid
    if path = "/" + wanted + ".mpd" then
        return { status: "200 OK", mime: "application/dash+xml", text: m.global.mpd }
    else if path = "/" + wanted + ".m3u8" then
        return { status: "200 OK", mime: "application/vnd.apple.mpegurl", text: m.global.mpd }
    end if
    live = "/" + m.global.liveId + "/"
    if m.global.liveId = "" or Left(path, Len(live)) <> live then return invalid
    rest = Mid(path, Len(live) + 1)
    if rest = "a.m3u8" or rest = "v.m3u8" then
        text = renditionPlaylist(Left(rest, 1) = "v")
        if text = "" then return invalid
        return { status: "200 OK", mime: "application/vnd.apple.mpegurl", text: text }
    else if Left(rest, 2) = "i/" or Left(rest, 3) = "vi/" then
        if Left(rest, 2) = "i/" then
            init = trackInit(Mid(rest, 3), "soun")
        else
            init = trackInit(Mid(rest, 4), "vide")
        end if
        if init = invalid then return invalid
        return { status: "200 OK", mime: "video/mp4", bytes: init.bytes }
    else if Left(rest, 2) = "s/" or Left(rest, 3) = "vs/" then
        if Left(rest, 2) = "s/" then
            seg = trackSegment(Mid(rest, 3), "soun")
        else
            seg = trackSegment(Mid(rest, 4), "vide")
        end if
        if seg = invalid then return invalid
        return { status: "200 OK", mime: "video/mp4", pieces: seg }
    end if
    return invalid
end function

' ---------- live renditions ----------

' The upstream media playlist pointed at our own init and segments, cut to
' sound or (when the stream lists its sound track first) to picture.
function renditionPlaylist(video as Boolean) as String
    body = upstreamPlaylist()
    if body = "" then return ""
    q = Chr(34)
    lf = Chr(10)
    out = ""
    for each line in body.Split(lf)
        line = line.Trim()
        if line = "" or Left(line, 13) = "#EXT-BILI-AUX" then
            ' Bilibili's own tags; Roku has no use for them
        else if Left(line, 8) = "#EXTINF:" then
            out = out + Left(line, Instr(1, line, ",")) + lf
        else if Left(line, 10) = "#EXT-X-MAP" then
            if video then
                out = out + "#EXT-X-MAP:URI=" + q + "vi/" + liveMapOf(line) + q + lf
            else
                out = out + "#EXT-X-MAP:URI=" + q + "i/" + liveMapOf(line) + q + lf
            end if
        else if Left(line, 1) = "#" then
            out = out + line + lf
        else
            if Left(line, 4) = "http" then line = Mid(line, Len(liveBaseOf(line)) + 1)
            if video then
                out = out + "vs/" + line + lf
            else
                out = out + "s/" + line + lf
            end if
        end if
    end for
    return out
end function

' { bytes, track } for the named init segment cut to one kind of track,
' cached until the stream changes its init.
function trackInit(name as String, kind as String) as Dynamic
    if m.inits = invalid then m.inits = {}
    key = m.global.liveId + "/" + name
    cached = m.inits[kind]
    if cached <> invalid then
        if cached.key = key then return cached
    end if
    raw = liveFetchBytes(m.global.liveBase + name, m.global.liveHeaders, 6000, "tmp:/live_srv_init.m4s")
    if raw = invalid then return invalid
    cut = mp4TrackInit(raw, kind)
    if cut.track = 0 then return invalid
    cut.key = key
    m.inits[kind] = cut
    return cut
end function

' Each rendition reloads the playlist about once a second and the CDN takes
' ~0.4s to answer; one fetch every 1.5s is plenty for an ~8 second window.
function upstreamPlaylist() as String
    if m.playlistClock = invalid then
        m.playlistClock = CreateObject("roTimespan")
        m.playlistSrc = ""
    end if
    if m.playlistSrc = m.global.liveSrc and m.playlistClock.TotalMilliseconds() < 1500 then return m.playlistBody
    r = liveFetch(m.global.liveSrc, m.global.liveHeaders, "", 5000)
    if r.code <> 200 then return ""
    m.playlistSrc = m.global.liveSrc
    m.playlistBody = r.body
    m.playlistClock.Mark()
    return r.body
end function

' The named segment cut to one kind of track, as pieces to send.
function trackSegment(name as String, kind as String) as Dynamic
    init = invalid
    if m.inits <> invalid then init = m.inits[kind]
    if init <> invalid then
        if Left(init.key, Len(m.global.liveId) + 1) <> m.global.liveId + "/" then init = invalid
    end if
    if init = invalid then
        ' a segment asked for before its init: find the init through the playlist
        init = trackInit(liveMapOf(upstreamPlaylist()), kind)
        if init = invalid then return invalid
    end if
    raw = rawSegment(name)
    if raw = invalid then return invalid
    return mp4TrackPieces(raw, init.track)
end function

' The audio and the video rendition ask for the same segment; keep the last
' few downloads so each is fetched once.
function rawSegment(name as String) as Dynamic
    if m.segCache = invalid then m.segCache = []
    key = m.global.liveId + "/" + name
    for each e in m.segCache
        if e.key = key then return e.raw
    end for
    raw = liveFetchBytes(m.global.liveBase + name, m.global.liveHeaders, 8000, "tmp:/live_srv_seg.m4s")
    if raw = invalid then return invalid
    m.segCache.Push({ key: key, raw: raw })
    if m.segCache.Count() > 4 then m.segCache.Shift()
    return raw
end function

sub sendBytes(c as Object, body as Object, start as Integer, length as Integer)
    sent = 0
    total = length
    tries = 0
    while sent < total and tries < 1500
        n = c.Send(body, start + sent, total - sent)
        if n > 0 then
            sent = sent + n
            tries = 0
        else
            tries = tries + 1
            sleep(2)
        end if
    end while
end sub

' the MPD is plain ASCII (URLs are escaped), so characters are bytes
sub sendAll(c as Object, text as String)
    sent = 0
    total = Len(text)
    tries = 0
    while sent < total and tries < 200
        n = c.SendStr(Mid(text, sent + 1))
        if n > 0 then
            sent = sent + n
        else
            tries = tries + 1
        end if
    end while
end sub
