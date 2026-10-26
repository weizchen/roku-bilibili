sub init()
    m.drawer = m.top.findNode("drawer")
    m.rows = m.top.findNode("rows")
    m.rows.rowLabelFont = cjkFont(30)
    hint = m.top.findNode("hint")
    hint.font = cjkFont(24)
    hint.text = "OK 播放　返回键收起"
    m.rows.observeField("rowItemSelected", "onSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

' One row sits low over the video; two take most of the screen.
sub onContent()
    c = m.top.content
    m.rows.content = c
    n = 1
    if c <> invalid then n = c.getChildCount()
    if n < 1 then n = 1
    if n > 2 then n = 2
    m.drawer.translation = [0, 1080 - n * 360 - 60]
end sub

sub onFocusChanged()
    if not m.top.hasFocus() then return
    f = m.top.focusItem
    if f <> invalid and f.Count() = 2 then m.rows.jumpToRowItem = f
    m.rows.setFocus(true)
end sub

sub onSelected()
    m.top.chosen = m.rows.rowItemSelected
end sub

' Keep every key away from the player underneath while open.
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return true
    if key = "back" or key = "up" then
        m.top.closed = true
    end if
    return true
end function
