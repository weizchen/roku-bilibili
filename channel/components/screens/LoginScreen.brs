sub init()
    m.heading = m.top.findNode("heading")
    m.qrBox = m.top.findNode("qrBox")
    m.qr = m.top.findNode("qr")
    m.qrBg = m.top.findNode("qrBg")
    m.steps = m.top.findNode("steps")
    m.status = m.top.findNode("status")
    m.buttons = m.top.findNode("buttons")
    m.note = m.top.findNode("note")
    m.poll = m.top.findNode("poll")
    m.leave = m.top.findNode("leave")

    m.heading.font = cjkFont(54)
    m.steps.font = cjkFont(34)
    m.status.font = cjkFont(34)
    m.note.font = cjkFont(24)
    m.buttons.textFont = cjkFont(32)
    m.buttons.focusedTextFont = cjkFont(32)
    m.buttons.focusBitmapUri = themed("pill")
    m.buttons.focusedTextColor = onAccent()
    m.status.color = accent()
    m.note.text = "登录信息只保存在这台电视上"

    m.poll.observeField("fire", "onPoll")
    m.leave.observeField("fire", "goBack")
    m.buttons.observeField("buttonSelected", "onButton")
    m.top.observeField("focusedChild", "onFocusChanged")
    m.key = ""
    m.expired = false

    if m.global.loggedIn then
        showLoggedIn()
    else
        requestQr()
    end if
end sub

sub showLoggedIn()
    m.heading.text = "已登录"
    m.qrBox.visible = false
    m.steps.visible = false
    m.status.visible = false
    m.buttons.buttons = ["退出登录", "返回"]
    m.buttons.visible = true
    m.buttons.setFocus(true)
end sub

sub requestQr()
    m.heading.text = "扫码登录哔哩哔哩"
    nl = Chr(10)
    m.steps.text = "1. 打开哔哩哔哩手机客户端" + nl + "2. 点右上角的扫一扫" + nl + "3. 扫描左边的二维码，在手机上确认"
    m.status.text = "正在生成二维码…"
    m.expired = false
    m.qr.removeChildrenIndex(m.qr.getChildCount(), 0)
    m.qrTask = api("qr", invalid, "onQr")
end sub

sub onQr(event as Object)
    res = event.getData()
    if not res.ok then
        m.status.text = "获取二维码失败：" + res.error + Chr(10) + "按 OK 重试"
        m.expired = true
        return
    end if
    m.key = strOf(res.data.key)
    drawQr(res.data.size, res.data.rows)
    m.status.text = "等待扫码…"
    m.poll.control = "start"
end sub

' Dark modules as one Rectangle per horizontal run, with the 4-module quiet zone.
sub drawQr(size as Integer, rows as Object)
    m.qr.removeChildrenIndex(m.qr.getChildCount(), 0)
    ms = Int(460 / (size + 8))
    side = ms * (size + 8)
    m.qrBg.width = side
    m.qrBg.height = side
    m.qr.translation = [ms * 4, ms * 4]
    for y = 0 to size - 1
        row = rows[y]
        x = 0
        while x < size
            if Mid(row, x + 1, 1) = "1" then
                x0 = x
                while x < size and Mid(row, x + 1, 1) = "1"
                    x = x + 1
                end while
                r = m.qr.createChild("Rectangle")
                r.color = "0x000000FF"
                r.translation = [x0 * ms, y * ms]
                r.width = (x - x0) * ms
                r.height = ms
            else
                x = x + 1
            end if
        end while
    end for
end sub

sub onPoll()
    if m.pollTask <> invalid and m.pollTask.state = "run" then return
    m.pollTask = api("qrpoll", { key: m.key }, "onPollResult")
end sub

sub onPollResult(event as Object)
    res = event.getData()
    if not res.ok then return   ' a dropped poll; the next one retries
    st = strOf(res.data.status)
    if st = "failed" then
        ' the code is spent once confirmed, so say why instead of polling into "expired"
        m.poll.control = "stop"
        m.expired = true
        m.status.text = strOf(res.data.message) + Chr(10) + "按 OK 重新生成二维码"
    else if st = "scanned" then
        m.status.text = "已扫码，请在手机上点确认"
    else if st = "expired" then
        m.poll.control = "stop"
        m.expired = true
        m.status.text = "二维码已过期，按 OK 刷新"
    else if st = "ok" then
        m.poll.control = "stop"
        m.status.text = "登录成功！"
        m.global.loggedIn = true
        m.leave.control = "start"
    end if
end sub

sub onButton()
    if m.buttons.buttonSelected = 0 then
        m.logoutTask = api("logout", invalid, "onLoggedOut")
    else
        goBack()
    end if
end sub

sub onLoggedOut(event as Object)
    m.global.loggedIn = false
    toast("已退出登录")
    goBack()
end sub

sub goBack()
    m.poll.control = "stop"
    navigate({ action: "back" })
end sub

sub onFocusChanged()
    if m.top.hasFocus() and m.buttons.visible then m.buttons.setFocus(true)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "OK" and m.expired then
        requestQr()
        return true
    else if key = "back" then
        goBack()
        return true
    end if
    return false
end function
