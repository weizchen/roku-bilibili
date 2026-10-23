sub init()
    m.video = m.top.findNode("video")
    m.hud = m.top.findNode("hud")
    m.loading = m.top.findNode("loading")
    m.error = m.top.findNode("error")
    m.menu = m.top.findNode("menu")
    m.hudTimer = m.top.findNode("hudTimer")
    m.quality = m.top.findNode("quality")
    m.top.findNode("title").font = cjkFont(42)
    m.top.findNode("sub").font = cjkFont(28)
    m.quality.font = cjkFont(30)
    m.quality.color = accent()
    hint = m.top.findNode("hint")
    hint.font = cjkFont(24)
    hint.text = "按下键切换画质"
    m.top.findNode("loadingText").font = cjkFont(28)
    m.top.findNode("loadingText").text = "正在连接直播…"
    m.error.font = cjkFont(32)
    spinner = m.top.findNode("spinner")
    spinner.poster.uri = themed("spinner")
    spinner.control = "start"
    m.video.bufferingBar.filledBarBlendColor = accent()
    m.video.retrievingBar.filledBarBlendColor = accent()

    m.qn = 0           ' 0 = best the account may watch
    m.qualities = []
    m.retries = 0
    m.video.observeField("state", "onState")
    m.hudTimer.observeField("fire", "hideHud")
    m.menu.observeField("chosen", "onQualityChosen")
    m.menu.observeField("closed", "closeMenu")
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

sub onRoom()
    r = m.top.room
    m.top.findNode("title").text = strOf(r.title)
    m.top.findNode("sub").text = strOf(r.up) + "    直播中"
    start()
end sub

sub start()
    m.video.control = "stop"
    m.error.visible = false
    m.loading.visible = true
    m.playTask = api("liveplay", { roomid: strOf(m.top.room.roomid), qn: m.qn }, "onPlay")
end sub

sub onPlay(event as Object)
    res = event.getData()
    if not res.ok then
        showError(res.error)
        return
    end if
    d = res.data
    m.qn = intOf(d.qn)
    m.qualities = d.qualities
    m.quality.text = strOf(d.quality_name)
    if strOf(d.sid) <> "" then
        ' the loopback server serves this room's master playlist and audio
        m.global.liveSrc = d.src
        m.global.liveBase = d.base
        m.global.liveHeaders = d.headers
        m.global.liveId = d.sid
        m.global.mpd = d.manifest
        m.global.mpdId = d.sid
    end if
    c = CreateObject("roSGNode", "ContentNode")
    c.url = strOf(d.url)
    c.streamFormat = "hls"
    c.live = true
    c.HttpHeaders = d.headers
    m.video.content = c
    m.video.control = "play"
    m.video.setFocus(true)
end sub

sub onState()
    s = m.video.state
    if s = "playing" then
        m.loading.visible = false
        m.retries = 0
        showHud()
    else if s = "error" or s = "finished" then
        ' stream addresses expire and broadcasts drop out; fetch a fresh one a couple of times
        if m.retries < 2 then
            m.retries = m.retries + 1
            start()
        else
            showError("直播中断了：" + strOf(m.video.errorMsg))
        end if
    end if
end sub

sub showHud()
    m.hud.visible = true
    m.hudTimer.control = "stop"
    m.hudTimer.control = "start"
end sub

sub hideHud()
    m.hud.visible = false
end sub

sub showError(text as String)
    m.loading.visible = false
    m.error.text = text + Chr(10) + Chr(10) + "按 OK 重试，按返回键退出"
    m.error.visible = true
end sub

' ---------- quality ----------

sub openQualityMenu()
    if m.qualities.Count() = 0 then return
    options = []
    for each q in m.qualities
        name = strOf(q.name)
        if intOf(q.qn) = m.qn then name = name + "（当前）"
        options.Push(name)
    end for
    m.menu.title = "画质"
    m.menu.message = ""
    m.menu.options = options
    m.menu.visible = true
    m.menu.setFocus(true)
end sub

sub onQualityChosen()
    q = m.qualities[m.menu.chosen]
    closeMenu()
    if q = invalid then return
    if intOf(q.qn) <> m.qn then
        m.qn = intOf(q.qn)
        m.retries = 0
        start()
    end if
end sub

sub closeMenu()
    m.menu.visible = false
    m.video.setFocus(true)
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.video.setFocus(true)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    ' the Video node keeps the OK press for itself; act on the release
    if key = "OK" and not press then
        if m.error.visible then
            m.retries = 0
            start()
        else
            showHud()
        end if
        return true
    end if
    if not press then return false
    if key = "back" then
        m.video.control = "stop"
        navigate({ action: "back" })
        return true
    else if key = "down" or key = "options" then
        openQualityMenu()
        return true
    else if key = "up" or key = "info" then
        showHud()
        return true
    end if
    return false
end function
