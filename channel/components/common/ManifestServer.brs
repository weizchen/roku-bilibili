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
                    if res.bytes = invalid then
                        length = Len(res.text)
                    else
                        length = res.bytes.Count()
                    end if
                    head = "HTTP/1.1 " + res.status + crlf + "Content-Type: " + res.mime + crlf + "Content-Length: " + length.ToStr() + crlf + "Cache-Control: no-store" + crlf + "Connection: close" + crlf + crlf
                    if res.bytes = invalid then
                        sendAll(c, head + res.text)
                    else
                        sendAll(c, head)
                        sendBytes(c, res.bytes)
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
    if rest = "a.m3u8" then
        text = audioPlaylist()
        if text = "" then return invalid
        return { status: "200 OK", mime: "application/vnd.apple.mpegurl", text: text }
    else if Left(rest, 2) = "i/" then
        init = audioInit(Mid(rest, 3))
        if init = invalid then return invalid
        return { status: "200 OK", mime: "video/mp4", bytes: init.bytes }
    else if Left(rest, 2) = "s/" then
        seg = audioSegment(Mid(rest, 3))
        if seg = invalid then return invalid
        return { status: "200 OK", mime: "video/mp4", bytes: seg }
    end if
    return invalid
end function

' ---------- live audio rendition ----------

' The upstream media playlist, pointed at our audio-only init and segments.
function audioPlaylist() as String
    r = liveFetch(m.global.liveSrc, m.global.liveHeaders, "", 5000)
    if r.code <> 200 then return ""
    q = Chr(34)
    lf = Chr(10)
    out = ""
    for each line in r.body.Split(lf)
        line = line.Trim()
        if line = "" or Left(line, 13) = "#EXT-BILI-AUX" then
            ' Bilibili's own tags; Roku has no use for them
        else if Left(line, 8) = "#EXTINF:" then
            out = out + Left(line, Instr(1, line, ",")) + lf
        else if Left(line, 10) = "#EXT-X-MAP" then
            out = out + "#EXT-X-MAP:URI=" + q + "i/" + liveMapOf(line) + q + lf
        else if Left(line, 1) = "#" then
            out = out + line + lf
        else if Left(line, 4) = "http" then
            out = out + "s/" + Mid(line, Len(liveBaseOf(line)) + 1) + lf
        else
            out = out + "s/" + line + lf
        end if
    end for
    return out
end function

' { bytes, track } for the named init segment, cached until the stream changes it.
function audioInit(name as String) as Dynamic
    key = m.global.liveId + "/" + name
    if m.audioInit <> invalid and m.audioInit.key = key then return m.audioInit
    raw = liveFetchBytes(m.global.liveBase + name, m.global.liveHeaders, 6000, "tmp:/live_srv_init.m4s")
    if raw = invalid then return invalid
    cut = mp4AudioInit(raw)
    if cut.track = 0 then return invalid
    cut.key = key
    m.audioInit = cut
    return cut
end function

function audioSegment(name as String) as Dynamic
    if m.audioInit = invalid or Left(m.audioInit.key, Len(m.global.liveId) + 1) <> m.global.liveId + "/" then
        ' a segment asked for before its init: find the init through the playlist
        r = liveFetch(m.global.liveSrc, m.global.liveHeaders, "", 5000)
        if r.code <> 200 or audioInit(liveMapOf(r.body)) = invalid then return invalid
    end if
    raw = liveFetchBytes(m.global.liveBase + name, m.global.liveHeaders, 8000, "tmp:/live_srv_seg.m4s")
    if raw = invalid then return invalid
    return mp4TrackSegment(raw, m.audioInit.track)
end function

sub sendBytes(c as Object, body as Object)
    sent = 0
    total = body.Count()
    tries = 0
    while sent < total and tries < 500
        n = c.Send(body, sent, total - sent)
        if n > 0 then
            sent = sent + n
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
