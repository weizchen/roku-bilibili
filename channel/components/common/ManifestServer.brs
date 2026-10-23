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
                    req = c.ReceiveStr(8192)
                    body = ""
                    status = "404 Not Found"
                    wanted = m.global.mpdId
                    if wanted <> "" and Instr(1, req, "/" + wanted + ".mpd") > 0 then
                        body = m.global.mpd
                        status = "200 OK"
                    end if
                    head = "HTTP/1.1 " + status + crlf + "Content-Type: application/dash+xml" + crlf + "Content-Length: " + Len(body).ToStr() + crlf + "Cache-Control: no-store" + crlf + "Connection: close" + crlf + crlf
                    sendAll(c, head + body)
                    c.Close()
                    clients.Delete(key)
                end if
            end if
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
