sub init()
    m.video = m.top.findNode("video")
    m.hud = m.top.findNode("hud")
    m.titleLabel = m.top.findNode("title")
    m.subLabel = m.top.findNode("sub")
    m.quality = m.top.findNode("quality")
    m.loading = m.top.findNode("loading")
    m.spinner = m.top.findNode("spinner")
    m.error = m.top.findNode("error")
    m.hudTimer = m.top.findNode("hudTimer")
    m.danmaku = m.top.findNode("danmaku")
    m.dmPanel = m.top.findNode("dmPanel")
    m.dmHint = m.top.findNode("dmHint")

    m.titleLabel.font = cjkFont(42)
    m.subLabel.font = cjkFont(28)
    m.quality.font = cjkFont(30)
    m.dmHint.font = cjkFont(24)
    m.top.findNode("loadingText").font = cjkFont(28)
    m.error.font = cjkFont(32)
    m.spinner.poster.uri = "pkg:/images/spinner.png"
    m.spinner.control = "start"

    pink = "0xFB7299FF"
    m.video.trickPlayBar.filledBarBlendColor = pink
    m.video.bufferingBar.filledBarBlendColor = pink
    m.video.retrievingBar.filledBarBlendColor = pink
    m.video.notificationInterval = 1

    m.video.observeField("state", "onState")
    m.video.observeField("position", "onPosition")
    m.hudTimer.observeField("fire", "hideHud")
    m.top.observeField("focusedChild", "onFocusChanged")
    m.lastSaved = 0
    m.lastReport = 0
    m.stateClock = CreateObject("roTimespan")
    m.shownOnce = false
    m.format = ""

    ' danmaku: the layer follows the video clock; settings live in the registry
    m.danmaku.video = m.video
    m.dmPanel.enabled = loadSetting("dm_on", "1") = "1"
    m.dmPanel.alpha = Val(loadSetting("dm_alpha", "0.8"))
    applyDanmakuSettings()
    m.dmPanel.observeField("enabled", "onDanmakuSettings")
    m.dmPanel.observeField("alpha", "onDanmakuSettings")
    m.dmPanel.observeField("closed", "closePanel")
    m.danmaku.observeField("count", "onDanmakuCount")
    onDanmakuCount()
end sub

sub applyDanmakuSettings()
    m.danmaku.enabled = m.dmPanel.enabled
    m.danmaku.opacity = m.dmPanel.alpha
end sub

sub onDanmakuSettings()
    applyDanmakuSettings()
    if m.dmPanel.enabled then
        saveSetting("dm_on", "1")
    else
        saveSetting("dm_on", "0")
    end if
    saveSetting("dm_alpha", Str(m.dmPanel.alpha).Trim())
    onDanmakuCount()
end sub

sub onDanmakuCount()
    n = m.danmaku.count
    m.dmPanel.count = n
    if not m.dmPanel.enabled then
        m.dmHint.text = "弹幕已关闭  ·  按下键设置"
    else if n > 0 then
        m.dmHint.text = "弹幕 " + n.ToStr() + " 条  ·  按下键设置"
    else
        m.dmHint.text = "按下键设置弹幕"
    end if
end sub

sub openPanel()
    m.dmPanel.visible = true
    m.dmPanel.setFocus(true)
end sub

sub closePanel()
    m.dmPanel.visible = false
    m.video.setFocus(true)
end sub

sub onRequest()
    r = m.top.request
    m.req = r
    startPart(intOf(r.index), intOf(r.startAt), "auto")
end sub

sub startPart(index as Integer, startAt as Integer, fmt as String)
    m.index = index
    m.startAt = startAt
    m.fmt = fmt
    m.part = m.req.pages[index]
    m.video.control = "stop"
    m.error.visible = false
    m.loading.visible = true
    m.titleLabel.text = m.req.title
    line = strOf(m.req.up)
    if m.req.pages.Count() > 1 then line = "P" + (index + 1).ToStr() + "  " + strOf(m.part.part) + "    " + line
    m.subLabel.text = line
    m.danmaku.cid = strOf(m.part.cid)
    m.playTask = api("play", { bvid: m.req.bvid, cid: strOf(m.part.cid), fmt: fmt }, "onPlay")
end sub

sub onPlay(event as Object)
    res = event.getData()
    if not res.ok then
        showError("无法获取播放地址：" + res.error)
        return
    end if
    d = res.data
    m.format = strOf(d.format)
    m.quality.text = strOf(d.quality_name)
    if m.format = "dash" then
        ' the loopback server hands this manifest to the player
        m.global.mpd = d.mpd
        m.global.mpdId = d.sid
    end if
    c = CreateObject("roSGNode", "ContentNode")
    c.url = strOf(d.url)
    c.streamFormat = m.format
    c.HttpHeaders = d.headers
    if m.startAt > 0 then c.PlayStart = m.startAt
    m.video.content = c
    m.video.control = "play"
    m.video.setFocus(true)
end sub

sub onState()
    m.stateClock.Mark()
    s = m.video.state
    if s = "playing" then
        m.loading.visible = false
        if not m.shownOnce then
            m.shownOnce = true
            showHud(true)
        end if
    else if s = "paused" then
        showHud(false)
    else if s = "error" then
        secs = Int(m.video.position)
        ' DASH is the 1080P path; if this TV chokes on it, the progressive MP4 still plays
        if m.format = "dash" then
            print "[player] dash failed ("; m.video.errorCode; ") "; m.video.errorMsg; " -> retry mp4"
            if secs > m.startAt then m.startAt = secs
            startPart(m.index, m.startAt, "mp4")
        else
            showError("播放出错：" + strOf(m.video.errorMsg) + " (" + strOf(m.video.errorCode) + ")")
        end if
    else if s = "finished" then
        save(true)
        if m.index + 1 < m.req.pages.Count() then
            m.shownOnce = false
            startPart(m.index + 1, 0, "auto")
        else
            navigate({ action: "back" })
        end if
    end if
end sub

sub onPosition()
    secs = Int(m.video.position)
    if Abs(secs - m.lastSaved) >= 15 then save(false)
end sub

sub save(done as Boolean, leaving = false as Boolean)
    secs = Int(m.video.position)
    dur = Int(m.video.duration)
    if done then secs = dur
    m.lastSaved = secs
    if dur <= 0 then return
    report(secs, done or leaving)
    ' finishing the last part clears the bookmark; finishing an earlier one points at the next
    if done and m.index + 1 < m.req.pages.Count() then
        saveProgress(m.req.bvid, m.index + 1, 0, 0)
        return
    end if
    saveProgress(m.req.bvid, m.index, secs, dur)
end sub

' Mirror the position into the account's history so the phone sees it too.
' Throttled to one call per 30s; finishing or leaving always reports.
sub report(secs as Integer, force as Boolean)
    if not m.global.loggedIn or strOf(m.req.aid) = "" then return
    now = CreateObject("roDateTime").AsSeconds()
    if not force and now - m.lastReport < 30 then return
    m.lastReport = now
    navigate({ action: "report", params: { aid: strOf(m.req.aid), cid: strOf(m.part.cid), progress: secs } })
end sub

sub showHud(autoHide as Boolean)
    m.hud.visible = true
    m.hudTimer.control = "stop"
    if autoHide then m.hudTimer.control = "start"
end sub

sub hideHud()
    if m.video.state <> "paused" then m.hud.visible = false
end sub

sub showError(text as String)
    m.loading.visible = false
    m.error.text = text + Chr(10) + Chr(10) + "按返回键退出"
    m.error.visible = true
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.video.setFocus(true)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    ' The Video node swallows the OK press (it uses it for its own bar), so the
    ' centre button toggles pause on release -- unless the press itself just moved
    ' the video (confirming a seek), which would make this a double toggle.
    if key = "OK" and not press then
        if m.stateClock.TotalMilliseconds() < 700 then return true
        if m.video.state = "playing" then
            m.video.control = "pause"
        else if m.video.state = "paused" then
            m.video.control = "resume"
        end if
        return true
    end if
    if not press then return false
    if key = "back" then
        if m.video.state = "playing" or m.video.state = "paused" or m.video.state = "buffering" then save(false, true)
        m.video.control = "stop"
        navigate({ action: "back" })
        return true
    ' Roku TVs keep * for their own picture menu during playback, so settings live on down
    else if key = "down" or key = "options" then
        openPanel()
        return true
    else if key = "up" or key = "info" then
        showHud(true)
        return true
    end if
    return false
end function
