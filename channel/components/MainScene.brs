sub init()
    m.top.backgroundColor = "0x0F0F14FF"
    m.top.backgroundUri = ""
    m.global.theme = themeByKey(loadSetting("theme", "yellow"))
    m.global.font = fontByKey(loadSetting("font", "kai"))
    m.global.observeField("font", "onFontChanged")
    m.global.observeField("loggedIn", "onLoggedIn")
    m.rebuildTimer = m.top.findNode("rebuildTimer")
    m.rebuildTimer.observeField("fire", "rebuildHome")
    m.stack = []
    m.reports = []   ' history reports in flight; kept here so they outlive the player
    m.container = m.top.findNode("stack")
    m.toast = m.top.findNode("toast")
    m.toastBg = m.top.findNode("toastBg")
    m.toastText = m.top.findNode("toastText")
    m.toastText.font = cjkFont(30)
    m.toastTimer = m.top.findNode("toastTimer")
    m.toastTimer.observeField("fire", "hideToast")

    m.server = CreateObject("roSGNode", "ManifestServer")
    m.server.control = "RUN"
    push(CreateObject("roSGNode", "HomeScreen"))
    ' a saved session may have expired since last time
    if m.global.loggedIn then m.navTask = api("nav", invalid, "onNav")
end sub

sub onLoggedIn()
    if m.global.loggedIn then
        m.navTask = api("nav", invalid, "onNav")
    else
        m.global.uname = ""
    end if
end sub

' confirms the session and fetches the name shown at the top right
sub onNav(event as Object)
    res = event.getData()
    if not res.ok then return
    if boolOf(res.data.logged_in) then
        m.global.uname = strOf(res.data.uname)
    else if m.global.loggedIn then
        m.global.loggedIn = false
        showToast("登录已过期，请重新扫码登录")
    end if
end sub

sub push(screen as Object)
    if m.stack.Count() > 0 then m.stack.Peek().visible = false
    m.container.appendChild(screen)
    m.stack.Push(screen)
    screen.visible = true
    screen.setFocus(true)
end sub

sub pop()
    if m.stack.Count() <= 1 then return
    screen = m.stack.Pop()
    m.container.removeChild(screen)
    top = m.stack.Peek()
    top.visible = true
    top.setFocus(true)
end sub

' Labels keep the Font node they were built with, so a new font means a new home
' screen (everything else is created afresh when opened). The font is picked in
' the settings rows on that very screen, so rebuild once the key press is over.
sub onFontChanged()
    m.toastText.font = cjkFont(30)
    m.rebuildTimer.control = "start"
end sub

sub rebuildHome()
    if m.stack.Count() <> 1 then return
    old = m.stack.Pop()
    m.container.removeChild(old)
    home = CreateObject("roSGNode", "HomeScreen")
    push(home)
    home.resume = { tab: "settings", row: 1 }
end sub

sub onRoute()
    a = m.top.nav
    if a = invalid then return
    action = strOf(a.action)
    if action = "back" then
        pop()
    else if action = "detail" then
        s = CreateObject("roSGNode", "DetailScreen")
        push(s)
        s.autoplay = boolOf(a.autoplay)
        s.bvid = strOf(a.bvid)
    else if action = "play" then
        s = CreateObject("roSGNode", "PlayerScreen")
        push(s)
        s.request = a
    else if action = "search" then
        push(CreateObject("roSGNode", "SearchScreen"))
    else if action = "live" then
        s = CreateObject("roSGNode", "LiveScreen")
        push(s)
        s.room = { roomid: a.roomid, title: a.title, up: a.up }
    else if action = "favorites" then
        s = CreateObject("roSGNode", "FavoriteScreen")
        push(s)
        s.folder = { id: a.id, title: a.title, count: a.count }
    else if action = "toast" then
        showToast(strOf(a.text))
    else if action = "report" then
        m.reports.Push(api("report", a.params, "onReported"))
    end if
end sub

sub onReported(event as Object)
    task = event.getRoSGNode()
    for i = 0 to m.reports.Count() - 1
        if m.reports[i].isSameNode(task) then
            m.reports.Delete(i)
            exit for
        end if
    end for
    res = event.getData()
    if not res.ok then print "[report] failed: "; res.error
end sub

' "Cast" from the computer: open the video's page and start playing at once.
sub onDeeplink()
    a = m.top.deeplink
    if a = invalid then return
    while m.stack.Count() > 1
        pop()
    end while
    onNavTo({ action: "detail", bvid: strOf(a.bvid), autoplay: true })
end sub

sub onNavTo(a as Object)
    m.top.nav = a
end sub

sub showToast(text as String)
    if text = "" then return
    m.toastText.width = 0
    m.toastText.text = text
    w = m.toastText.boundingRect().width + 80
    if w > 1600 then w = 1600
    m.toastText.width = w
    m.toastBg.width = w
    m.toast.translation = [(1920 - w) / 2, 940]
    m.toast.visible = true
    m.toastTimer.control = "stop"
    m.toastTimer.control = "start"
end sub

sub hideToast()
    m.toast.visible = false
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "back" and m.stack.Count() > 1 then
        pop()
        return true
    end if
    return false
end function
