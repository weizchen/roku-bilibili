' Bilibili live fMP4 carries audio and video in one stream, and Roku plays
' that without sound. These helpers cut the audio track out so it can be
' served as its own HLS rendition next to the untouched video.

function mp4U32(b as Object, i as Integer) as Integer
    return ((b[i] * 256 + b[i + 1]) * 256 + b[i + 2]) * 256 + b[i + 3]
end function

function mp4Type(b as Object, i as Integer) as String
    return Chr(b[i + 4]) + Chr(b[i + 5]) + Chr(b[i + 6]) + Chr(b[i + 7])
end function

sub mp4PushU32(out as Object, v as Integer)
    out.Push((v \ 16777216) and 255)
    out.Push((v \ 65536) and 255)
    out.Push((v \ 256) and 255)
    out.Push(v and 255)
end sub

sub mp4SetU32(out as Object, i as Integer, v as Integer)
    out[i] = (v \ 16777216) and 255
    out[i + 1] = (v \ 65536) and 255
    out[i + 2] = (v \ 256) and 255
    out[i + 3] = v and 255
end sub

sub mp4Copy(out as Object, b as Object, start as Integer, length as Integer)
    for k = start to start + length - 1
        out.Push(b[k])
    end for
end sub

sub mp4PushBox(out as Object, typ as String, payload as Object)
    mp4PushU32(out, payload.Count() + 8)
    for k = 1 to 4
        out.Push(Asc(Mid(typ, k, 1)))
    end for
    out.Append(payload)
end sub

' Index of the first occurrence of a four-letter tag inside [start, finish).
function mp4Find(b as Object, tag as String, start as Integer, finish as Integer) as Integer
    c0 = Asc(Mid(tag, 1, 1))
    c1 = Asc(Mid(tag, 2, 1))
    c2 = Asc(Mid(tag, 3, 1))
    c3 = Asc(Mid(tag, 4, 1))
    for k = start to finish - 4
        if b[k] = c0 and b[k + 1] = c1 and b[k + 2] = c2 and b[k + 3] = c3 then return k
    end for
    return -1
end function

' "avc1.640028" from the init segment's avcC box.
function mp4AvcCodec(init as Object) as String
    i = mp4Find(init, "avcC", 0, init.Count())
    if i < 0 then return "avc1.640028"
    return "avc1." + mp4Hex2(init[i + 5]) + mp4Hex2(init[i + 6]) + mp4Hex2(init[i + 7])
end function

function mp4Hex2(v as Integer) as String
    digits = "0123456789abcdef"
    return Mid(digits, (v \ 16) + 1, 1) + Mid(digits, (v and 15) + 1, 1)
end function

' Handler ("vide", "soun") of the first track in the init segment's moov.
' Roku treats the first track of a muxed stream as the picture.
function mp4FirstTrack(init as Object) as String
    m4 = mp4Find(init, "moov", 0, init.Count())
    if m4 < 0 then return ""
    t = mp4Find(init, "trak", m4, init.Count())
    if t < 0 then return ""
    h = mp4Find(init, "hdlr", t, init.Count())
    if h < 0 or h + 16 > init.Count() then return ""
    return Chr(init[h + 12]) + Chr(init[h + 13]) + Chr(init[h + 14]) + Chr(init[h + 15])
end function

' The init segment with only one kind of track ("soun" or "vide"):
' { bytes, track } (track 0 when there is none).
function mp4TrackInit(init as Object, kind as String) as Object
    out = CreateObject("roByteArray")
    track = 0
    n = init.Count()
    i = 0
    while i + 8 <= n
        size = mp4U32(init, i)
        if size < 8 or i + size > n then exit while
        if mp4Type(init, i) <> "moov" then
            mp4Copy(out, init, i, size)
        else
            moov = CreateObject("roByteArray")
            mvexAt = -1
            mvexSize = 0
            j = i + 8
            while j + 8 <= i + size
                s2 = mp4U32(init, j)
                if s2 < 8 then exit while
                t2 = mp4Type(init, j)
                if t2 = "trak" then
                    h = mp4Find(init, "hdlr", j, j + s2)
                    if h >= 0 and mp4Find(init, kind, h + 12, h + 16) = h + 12 then
                        mp4Copy(moov, init, j, s2)
                        t = mp4Find(init, "tkhd", j, j + s2)
                        if init[t + 4] = 0 then track = mp4U32(init, t + 16) else track = mp4U32(init, t + 24)
                    end if
                else if t2 = "mvex" then
                    mvexAt = j     ' needs the track id, which may come later
                    mvexSize = s2
                else
                    mp4Copy(moov, init, j, s2)
                end if
                j = j + s2
            end while
            if mvexAt >= 0 then
                mvex = CreateObject("roByteArray")
                k = mvexAt + 8
                while k + 8 <= mvexAt + mvexSize
                    s3 = mp4U32(init, k)
                    if s3 < 8 then exit while
                    if mp4Type(init, k) <> "trex" or mp4U32(init, k + 12) = track then mp4Copy(mvex, init, k, s3)
                    k = k + s3
                end while
                mp4PushBox(moov, "mvex", mvex)
            end if
            mp4PushBox(out, "moov", moov)
        end if
        i = i + size
    end while
    return { bytes: out, track: track }
end function

' A media segment cut down to one track: each moof keeps only that track's
' traf, and its mdat only that track's samples, with the offsets rewritten.
' Returned as pieces to send in order -- small new headers, and slices of the
' original segment for the samples, so sample data is never copied byte by byte:
' { pieces: [{ b: roByteArray, s: start, n: length }], length: total }
function mp4TrackPieces(seg as Object, track as Integer) as Object
    out = { pieces: [], length: 0 }
    n = seg.Count()
    i = 0
    while i + 8 <= n
        size = mp4U32(seg, i)
        if size < 8 or i + size > n then exit while
        if mp4Type(seg, i) = "moof" then mp4PushFragment(out, seg, i, size, track)
        i = i + size
    end while
    return out
end function

sub mp4PushFragment(out as Object, seg as Object, moofAt as Integer, moofSize as Integer, track as Integer)
    mfhdAt = -1
    mfhdSize = 0
    trafAt = -1
    trafSize = 0
    j = moofAt + 8
    while j + 8 <= moofAt + moofSize
        s2 = mp4U32(seg, j)
        if s2 < 8 then exit while
        t2 = mp4Type(seg, j)
        if t2 = "mfhd" then
            mfhdAt = j
            mfhdSize = s2
        else if t2 = "traf" and trafAt < 0 then
            t = mp4Find(seg, "tfhd", j, j + s2)
            if t >= 0 and mp4U32(seg, t + 8) = track then
                trafAt = j
                trafSize = s2
            end if
        end if
        j = j + s2
    end while
    if mfhdAt < 0 or trafAt < 0 then return

    ' every trun's samples: where they are in the segment and how long
    runs = []
    k = trafAt + 8
    while k + 8 <= trafAt + trafSize
        s3 = mp4U32(seg, k)
        if s3 < 8 then exit while
        if mp4Type(seg, k) = "trun" then
            flags = (seg[k + 9] * 256 + seg[k + 10]) * 256 + seg[k + 11]
            if (flags and 1) = 0 or (flags and &h200) = 0 then return   ' needs explicit offset and sizes
            count = mp4U32(seg, k + 12)
            p = k + 20
            if (flags and 4) <> 0 then p = p + 4
            sizeAt = 0
            if (flags and &h100) <> 0 then sizeAt = 4
            stride = 4 + sizeAt
            if (flags and &h400) <> 0 then stride = stride + 4
            if (flags and &h800) <> 0 then stride = stride + 4
            total = 0
            for c = 0 to count - 1
                total = total + mp4U32(seg, p + c * stride + sizeAt)
            end for
            runs.Push({ trun: k - trafAt, start: moofAt + mp4U32(seg, k + 16), length: total })
        end if
        k = k + s3
    end while

    head = CreateObject("roByteArray")
    moofLen = 8 + mfhdSize + trafSize
    mp4PushU32(head, moofLen)
    for each ch in ["m", "o", "o", "f"]
        head.Push(Asc(ch))
    end for
    mp4Copy(head, seg, mfhdAt, mfhdSize)
    trafOut = head.Count()
    mp4Copy(head, seg, trafAt, trafSize)
    cursor = moofLen + 8
    mdatLen = 8
    for each r in runs
        mp4SetU32(head, trafOut + r.trun + 16, cursor)
        cursor = cursor + r.length
        mdatLen = mdatLen + r.length
    end for
    mp4PushU32(head, mdatLen)
    for each ch in ["m", "d", "a", "t"]
        head.Push(Asc(ch))
    end for
    out.pieces.Push({ b: head, s: 0, n: head.Count() })
    out.length = out.length + head.Count()
    for each r in runs
        out.pieces.Push({ b: seg, s: r.start, n: r.length })
        out.length = out.length + r.length
    end for
end sub

' ---------- fetching (works on any thread that may block) ----------

' One transfer object per thread, so the TLS connection to the CDN stays open
' between the once-a-second playlist and segment requests.
function liveFetch(url as String, headers as Object, toFile as String, timeoutMs as Integer) as Object
    if m.liveXfer = invalid then
        m.livePort = CreateObject("roMessagePort")
        m.liveXfer = CreateObject("roUrlTransfer")
        m.liveXfer.SetMessagePort(m.livePort)
        m.liveXfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
        m.liveXfer.InitClientCertificates()
    end if
    x = m.liveXfer
    x.SetUrl(url)
    hdrs = {}
    for each h in headers
        colon = Instr(1, h, ":")
        if colon > 1 then hdrs[Left(h, colon - 1)] = Mid(h, colon + 2)
    end for
    x.SetHeaders(hdrs)
    out = { code: 0, body: "" }
    if toFile = "" then
        sent = x.AsyncGetToString()
    else
        sent = x.AsyncGetToFile(toFile)
    end if
    if not sent then return out
    msg = wait(timeoutMs, m.livePort)
    if type(msg) = "roUrlEvent" then
        out.code = msg.GetResponseCode()
        if toFile = "" then out.body = msg.GetString()
    else
        x.AsyncCancel()
        ' a cancelled transfer can still post its event later; start clean next time
        m.liveXfer = invalid
    end if
    return out
end function

' path: a tmp: file of the caller's own, since tasks run side by side
function liveFetchBytes(url as String, headers as Object, timeoutMs as Integer, path as String) as Dynamic
    r = liveFetch(url, headers, path, timeoutMs)
    if r.code <> 200 then return invalid
    b = CreateObject("roByteArray")
    if not b.ReadFile(path) then return invalid
    return b
end function

' "https://host/dir/index.m3u8?x=1" -> "https://host/dir/"
function liveBaseOf(url as String) as String
    q = Instr(1, url, "?")
    if q > 0 then url = Left(url, q - 1)
    last = 0
    k = Instr(1, url, "/")
    while k > 0
        last = k
        k = Instr(k + 1, url, "/")
    end while
    return Left(url, last)
end function

' The init segment named by #EXT-X-MAP, or "".
function liveMapOf(playlist as String) as String
    i = Instr(1, playlist, "#EXT-X-MAP:URI=" + Chr(34))
    if i = 0 then return ""
    start = i + 16
    finish = Instr(start, playlist, Chr(34))
    if finish = 0 then return ""
    return Mid(playlist, start, finish - start)
end function
