sub init()
    m.kb = m.top.findNode("kb")
    m.sug = m.top.findNode("sug")
    m.sugTitle = m.top.findNode("sugTitle")
    m.grid = m.top.findNode("grid")
    m.resultTitle = m.top.findNode("resultTitle")
    m.message = m.top.findNode("message")
    m.spinner = m.top.findNode("spinner")
    m.debounce = m.top.findNode("debounce")

    m.top.findNode("heading").font = cjkFont(44)
    m.top.findNode("hint").font = cjkFont(24)
    m.sugTitle.font = cjkFont(28)
    m.resultTitle.font = cjkFont(36)
    m.message.font = cjkFont(30)
    m.sug.font = cjkFont(28)
    m.sug.focusedFont = cjkFont(28)
    m.spinner.poster.uri = themed("spinner")
    m.sugTitle.color = accent()
    m.sug.focusBitmapUri = themed("chip")
    m.sug.focusedColor = onAccent()

    m.query = ""
    m.focusNode = m.kb
    m.kb.observeField("text", "onTyped")
    m.debounce.observeField("fire", "onDebounced")
    m.sug.observeField("itemSelected", "onSuggestion")
    m.grid.observeField("itemSelected", "onItemSelected")
    m.top.observeField("focusedChild", "onFocusChanged")

    m.hotTask = api("hotsearch", invalid, "onSuggestions")
    showMessage("输入关键词开始搜索")
end sub

sub onTyped()
    m.debounce.control = "stop"
    m.debounce.control = "start"
end sub

sub onDebounced()
    text = m.kb.text.Trim()
    if text = "" then
        m.sugTitle.text = "热门搜索"
        m.hotTask = api("hotsearch", invalid, "onSuggestions")
        return
    end if
    m.sugTitle.text = "联想"
    m.sugTask = api("suggest", { q: text }, "onSuggestions")
    search(text)
end sub

sub onSuggestions(event as Object)
    res = event.getData()
    if not res.ok then return
    content = CreateObject("roSGNode", "ContentNode")
    for each word in res.data.items
        item = content.createChild("ContentNode")
        item.title = "  " + strOf(word)
    end for
    m.sug.content = content
end sub

sub onSuggestion()
    item = m.sug.content.getChild(m.sug.itemSelected)
    if item = invalid then return
    search(item.title.Trim())
end sub

sub search(q as String)
    if q = m.query then return
    m.query = q
    m.resultTitle.text = "“" + q + "” 的搜索结果"
    m.grid.visible = false
    m.message.visible = false
    m.spinner.visible = true
    m.spinner.control = "start"
    m.searchTask = api("search", { q: q }, "onResults", q)
end sub

sub onResults(event as Object)
    if event.getRoSGNode().tag <> m.query then return   ' a newer query is in flight
    m.spinner.visible = false
    m.spinner.control = "stop"
    res = event.getData()
    if not res.ok then
        showMessage("搜索失败：" + res.error)
        return
    end if
    content = cardsToContent(res.data.items, CreateObject("roSGNode", "ContentNode"))
    if content.getChildCount() = 0 then
        showMessage("没有找到相关视频")
        return
    end if
    m.grid.content = content
    m.grid.jumpToItem = 0
    m.grid.visible = true
end sub

sub showMessage(text as String)
    m.grid.visible = false
    m.message.text = text
    m.message.visible = true
end sub

sub onItemSelected()
    item = m.grid.content.getChild(m.grid.itemSelected)
    if item <> invalid then navigate({ action: "detail", bvid: item.bvid })
end sub

sub setFocusNode(node as Object)
    m.focusNode = node
    node.setFocus(true)
end sub

sub onFocusChanged()
    if m.top.hasFocus() then m.focusNode.setFocus(true)
end sub

function hasResults() as Boolean
    return m.grid.visible and m.grid.content <> invalid
end function

function hasSuggestions() as Boolean
    if m.sug.content = invalid then return false
    return m.sug.content.getChildCount() > 0
end function

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if m.kb.isInFocusChain() then
        if key = "right" and hasResults() then
            setFocusNode(m.grid)
            return true
        else if key = "down" and hasSuggestions() then
            setFocusNode(m.sug)
            return true
        end if
    else if m.sug.isInFocusChain() then
        if key = "up" then
            setFocusNode(m.kb)
            return true
        else if key = "right" and hasResults() then
            setFocusNode(m.grid)
            return true
        end if
    else if m.grid.isInFocusChain() then
        if key = "left" or key = "back" then
            setFocusNode(m.kb)
            return true
        end if
    end if
    return false
end function
