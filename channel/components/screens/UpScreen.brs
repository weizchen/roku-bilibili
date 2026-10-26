sub init()
    m.grid = m.top.findNode("grid")
    m.order = m.top.findNode("order")
    m.message = m.top.findNode("message")
    m.spinner = m.top.findNode("spinner")
    m.top.findNode("name").font = cjkFont(46)
    m.top.findNode("stats").font = cjkFont(26)
    m.top.findNode("stats").color = accent()
    m.top.findNode("sign").font = cjkFont(24)
    m.message.font = cjkFont(32)
    m.order.textFont = cjkFont(30)
    m.order.focusedTextFont = cjkFont(30)
    m.order.focusBitmapUri = themed("pill")
    m.order.focusedTextColor = onAccent()
    m.order.buttons = ["最新发布", "最多播放"]
    m.spinner.poster.uri = themed("spinner")
    m.spinner.control = "start"
    m.orders = ["pubdate", "views"]
    m.orderIndex = 0
    m.task = invalid
    m.infoTask = invalid
    ' focus (and itemFocused) arrives as soon as the screen is pushed, before `uploader`
    resetList()
    m.grid.observeField("itemSelected", "onItemSelected")
    m.grid.observeField("itemFocused", "onItemFocused")
    m.order.observeField("buttonSelected", "onOrder")
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

sub resetList()
    m.page = 1
    m.last = false
    m.content = CreateObject("roSGNode", "ContentNode")
    m.grid.content = m.content
end sub

sub onUploader()
    u = m.top.uploader
    m.top.findNode("name").text = strOf(u.name)
    m.infoTask = api("upinfo", { mid: strOf(u.mid) }, "onInfo")
    loadPage()
end sub

sub onInfo(event as Object)
    res = event.getData()
    if not res.ok then return
    d = res.data
    m.top.findNode("avatar").uri = strOf(d.face)
    if strOf(d.name) <> "" then m.top.findNode("name").text = strOf(d.name)
    parts = []
    if intOf(d.level) > 0 then parts.Push("Lv" + intOf(d.level).ToStr())
    parts.Push("粉丝 " + strOf(d.fans))
    parts.Push(intOf(d.videos).ToStr() + " 个视频")
    stats = parts.Join("  ·  ")
    if strOf(d.official) <> "" then stats = stats + "  ·  " + strOf(d.official)
    m.top.findNode("stats").text = stats
    m.top.findNode("sign").text = strOf(d.sign)
end sub

sub loadPage()
    u = m.top.uploader
    if m.last or type(u) <> "roAssociativeArray" then return
    if isNil(u.mid) then return
    if m.task <> invalid then
        if m.task.state = "run" then return
    end if
    m.task = api("upvideos", { mid: strOf(u.mid), page: m.page, order: m.orders[m.orderIndex] }, "onLoaded")
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
        showMessage("这位 UP 主还没有投稿")
    else
        m.message.visible = false
        m.grid.visible = true
        if m.top.isInFocusChain() and not m.order.isInFocusChain() and not m.grid.hasFocus() then m.grid.setFocus(true)
    end if
end sub

sub showMessage(text as String)
    m.grid.visible = false
    m.message.text = text
    m.message.visible = true
end sub

sub onOrder()
    i = m.order.buttonSelected
    if i = m.orderIndex then
        if m.content.getChildCount() > 0 then m.grid.setFocus(true)
        return
    end if
    m.orderIndex = i
    if m.task <> invalid then m.task.unobserveField("response")
    m.task = invalid
    resetList()
    m.grid.setFocus(true)
    m.spinner.visible = true
    m.spinner.control = "start"
    loadPage()
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

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "up" and m.grid.isInFocusChain() then
        m.order.focusButton = m.orderIndex
        m.order.setFocus(true)
        return true
    else if key = "down" and m.order.isInFocusChain() and m.content.getChildCount() > 0 then
        m.order.focusButton = m.orderIndex
        m.grid.setFocus(true)
        return true
    end if
    return false
end function
