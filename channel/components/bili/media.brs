' Stream selection and MPD generation. Bilibili DASH is one file per track with
' byte ranges; Roku only accepts a manifest over HTTP, so the channel serves
' this MPD from its own loopback server (ManifestServer) and the player fetches
' the segments straight from the CDN with mediaHeaders().

function qualityName(id as Integer, height as Integer) as String
    names = { q6: "240P", q16: "360P", q32: "480P", q64: "720P", q74: "720P60", q80: "1080P", q112: "1080P+", q116: "1080P60", q120: "4K" }
    n = names["q" + id.ToStr()]
    if not isNil(n) then return n
    return height.ToStr() + "P"
end function

function codecFamily(codecs as String) as String
    c = LCase(codecs)
    if Left(c, 3) = "avc" then return "avc"
    if Left(c, 3) = "hev" or Left(c, 3) = "hvc" then return "hevc"
    if Left(c, 3) = "av0" then return "av1"
    return "other"
end function

' Bilibili tags its 1080P AVC as High@5.0 (avc1.640032). This TV advertises H.264
' up to level 4.2 and silently drops such representations, although 1080p decodes
' fine, so the manifest declares at most 4.2.
function rokuCodecs(codecs as String) as String
    if Len(codecs) = 11 and LCase(Left(codecs, 7)) = "avc1.64" then
        if UCase(Mid(codecs, 10, 2)) > "2A" then return Left(codecs, 9) + "2A"
    end if
    return codecs
end function

function trackOf(raw as Object, mime as String) as Object
    seg = raw.segment_base
    if type(seg) <> "roAssociativeArray" then seg = raw.SegmentBase
    if type(seg) <> "roAssociativeArray" then seg = {}
    init = strOf(firstOf([seg.initialization, seg.Initialization]))
    index = strOf(firstOf([seg.index_range, seg.indexRange]))
    return {
        url: strOf(firstOf([raw.baseUrl, raw.base_url]))
        codecs: rokuCodecs(strOf(raw.codecs))
        bandwidth: intOf(raw.bandwidth)
        mime: mime
        init: init
        index: index
        width: intOf(raw.width)
        height: intOf(raw.height)
        frameRate: strOf(firstOf([raw.frameRate, raw.frame_rate]))
        sar: strOf(firstOf([raw.sar, "1:1"]))
        qid: intOf(raw.id)
    }
end function

' Every AVC rendition up to 1080P (Roku adapts between them) plus the best AAC track.
function selectTracks(dash as Object) as Dynamic
    best = {}
    for each v in dash.video
        if codecFamily(strOf(v.codecs)) = "avc" and intOf(v.height) <= 1080 then
            key = "q" + intOf(v.id).ToStr()
            if best[key] = invalid or intOf(v.bandwidth) > best[key].bandwidth then best[key] = trackOf(v, "video/mp4")
        end if
    end for
    videos = []
    for each k in best
        videos.Push(best[k])
    end for
    if videos.Count() = 0 then return invalid
    videos.SortBy("bandwidth")

    audio = invalid
    if type(dash.audio) = "roArray" then
        for each a in dash.audio
            if Left(strOf(a.codecs), 4) = "mp4a" then
                if audio = invalid or intOf(a.bandwidth) > audio.bandwidth then audio = trackOf(a, "audio/mp4")
            end if
        end for
    end if
    if audio = invalid then return invalid
    return { videos: videos, audio: audio }
end function

function xmlEsc(s as String) as String
    return s.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;").Replace(Chr(34), "&quot;")
end function

function frameRateOf(s as String) as String
    f = Val(s)
    if f <= 0 then return "25"
    r = Int(f + 0.5)
    if Abs(f - r) < 0.001 then return r.ToStr()
    return Int(f * 1000 + 0.5).ToStr() + "/1000"
end function

function representation(id as String, t as Object) as String
    q = Chr(34)
    if Left(id, 1) = "v" then
        attrs = "width=" + q + t.width.ToStr() + q + " height=" + q + t.height.ToStr() + q + " frameRate=" + q + frameRateOf(t.frameRate) + q + " sar=" + q + xmlEsc(t.sar) + q
        extra = ""
    else
        attrs = "audioSamplingRate=" + q + "44100" + q
        extra = "<AudioChannelConfiguration schemeIdUri=" + q + "urn:mpeg:dash:23003:3:audio_channel_configuration:2011" + q + " value=" + q + "2" + q + "/>"
    end if
    return "<Representation id=" + q + id + q + " codecs=" + q + xmlEsc(t.codecs) + q + " bandwidth=" + q + t.bandwidth.ToStr() + q + " " + attrs + ">" + extra + "<BaseURL>" + xmlEsc(t.url) + "</BaseURL><SegmentBase indexRange=" + q + t.index + q + "><Initialization range=" + q + t.init + q + "/></SegmentBase></Representation>"
end function

function buildMpd(tracks as Object, duration as Integer) as String
    q = Chr(34)
    dur = "PT" + duration.ToStr() + "S"
    vids = ""
    for i = 0 to tracks.videos.Count() - 1
        vids = vids + representation("v" + i.ToStr(), tracks.videos[i])
    end for
    adapt = " segmentAlignment=" + q + "true" + q + " startWithSAP=" + q + "1" + q + " subsegmentStartsWithSAP=" + q + "1" + q
    return "<?xml version=" + q + "1.0" + q + " encoding=" + q + "utf-8" + q + "?>" + Chr(10) + "<MPD xmlns=" + q + "urn:mpeg:dash:schema:mpd:2011" + q + " profiles=" + q + "urn:mpeg:dash:profile:isoff-on-demand:2011" + q + " type=" + q + "static" + q + " mediaPresentationDuration=" + q + dur + q + " minBufferTime=" + q + "PT2S" + q + "><Period id=" + q + "0" + q + " duration=" + q + dur + q + "><AdaptationSet id=" + q + "1" + q + " contentType=" + q + "video" + q + " mimeType=" + q + "video/mp4" + q + adapt + ">" + vids + "</AdaptationSet><AdaptationSet id=" + q + "2" + q + " contentType=" + q + "audio" + q + " mimeType=" + q + "audio/mp4" + q + " lang=" + q + "zh" + q + adapt + ">" + representation("a0", tracks.audio) + "</AdaptationSet></Period></MPD>"
end function
