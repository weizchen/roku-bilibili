sub init()
    m.panel = m.top.findNode("panel")
    m.titleLabel = m.top.findNode("titleLabel")
    m.messageLabel = m.top.findNode("messageLabel")
    m.list = m.top.findNode("list")
    m.titleLabel.font = cjkFont(36)
    m.messageLabel.font = cjkFont(26)
    m.list.font = cjkFont(30)
    m.list.focusedFont = cjkFont(30)
    m.list.observeField("itemSelected", "onSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

sub onOptions()
    content = CreateObject("roSGNode", "ContentNode")
    for each text in m.top.options
        item = content.createChild("ContentNode")
        item.title = "  " + text
    end for
    m.list.content = content
    m.list.jumpToItem = 0
    layout()
end sub

' stack title, optional message and the options, then size the panel around them
sub layout()
    m.titleLabel.text = m.top.title
    m.messageLabel.text = m.top.message
    y = 340 + Int(m.titleLabel.boundingRect().height) + 20
    if m.top.message <> "" then
        m.messageLabel.visible = true
        m.messageLabel.translation = [610, y]
        y = y + Int(m.messageLabel.boundingRect().height) + 24
    else
        m.messageLabel.visible = false
    end if
    m.list.translation = [600, y]
    n = 0
    if m.top.options <> invalid then n = m.top.options.Count()
    m.panel.height = (y - 300) + n * 70 + 30
end sub

sub onSelected()
    m.top.chosen = m.list.itemSelected
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.list.setFocus(true)
end sub

' modal: swallow everything the list does not use
function onKeyEvent(key as String, press as Boolean) as Boolean
    if press and (key = "back" or key = "options") then m.top.closed = true
    return true
end function
