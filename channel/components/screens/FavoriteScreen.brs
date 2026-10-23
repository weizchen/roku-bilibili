sub init()
    m.grid = m.top.findNode("grid")
    m.message = m.top.findNode("message")
    m.spinner = m.top.findNode("spinner")
    m.top.findNode("heading").font = cjkFont(46)
    m.top.findNode("sub").font = cjkFont(26)
    m.message.font = cjkFont(32)
    m.spinner.poster.uri = themed("spinner")
    m.spinner.control = "start"
    m.page = 1
    m.last = false
    m.task = invalid
    ' focus (and itemFocused) arrives as soon as the screen is pushed, before `folder`
    m.content = CreateObject("roSGNode", "ContentNode")
    m.grid.content = m.content
    m.grid.observeField("itemSelected", "onItemSelected")
    m.grid.observeField("itemFocused", "onItemFocused")
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

sub onFolder()
    f = m.top.folder
    m.top.findNode("heading").text = strOf(f.title)
    m.top.findNode("sub").text = intOf(f.count).ToStr() + " 个视频"
    loadPage()
end sub

sub loadPage()
    f = m.top.folder
    if m.last or type(f) <> "roAssociativeArray" then return
    if isNil(f.id) then return
    if m.task <> invalid then
        if m.task.state = "run" then return
    end if
    m.task = api("favlist", { id: strOf(m.top.folder.id), page: m.page }, "onLoaded")
end sub

sub onLoaded(event as Object)
    m.spinner.visible = false
    m.spinner.control = "stop"
    res = event.getData()
    if not res.ok then
        if m.content.getChildCount() = 0 then showMessage("加载失败：" + res.error)
        return
    end if
    cardsToContent(res.data.items, m.content)
    m.last = boolOf(res.data.last)
    m.page = m.page + 1
    if m.content.getChildCount() = 0 then
        showMessage("这个收藏夹是空的")
    else if m.top.isInFocusChain() and not m.grid.hasFocus() then
        m.grid.setFocus(true)
    end if
end sub

sub showMessage(text as String)
    m.grid.visible = false
    m.message.text = text
    m.message.visible = true
end sub

' keep a page ahead of the highlight
sub onItemFocused()
    if m.grid.itemFocused >= m.content.getChildCount() - 8 then loadPage()
end sub

sub onItemSelected()
    item = m.content.getChild(m.grid.itemSelected)
    if item <> invalid then navigate({ action: "detail", bvid: item.bvid })
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.grid.setFocus(true)
end sub
