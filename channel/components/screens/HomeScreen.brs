sub init()
    m.tabsDef = [
        { key: "rcmd", name: "推荐" }
        { key: "popular", name: "热门" }
        { key: "rank", name: "排行" }
        { key: "history", name: "历史" }
        { key: "search", name: "搜索" }
        { key: "me", name: "我的" }
        { key: "settings", name: "设置" }
    ]
    m.grid = m.top.findNode("grid")
    m.tabsGroup = m.top.findNode("tabs")
    m.message = m.top.findNode("message")
    m.spinner = m.top.findNode("spinner")
    m.account = m.top.findNode("account")
    m.top.findNode("brand").font = cjkFont(40)
    m.account.font = cjkFont(26)
    m.hint = m.top.findNode("hint")
    m.hint.font = cjkFont(22)
    m.hint.text = "按 * 键删除历史记录"
    m.menu = m.top.findNode("menu")
    m.menu.observeField("chosen", "onMenuChosen")
    m.menu.observeField("closed", "closeMenu")
    m.historyCursor = {}
    m.historyEnd = false
    m.message.font = cjkFont(32)

    buildTabs()
    m.cache = {}       ' tab key -> ContentNode
    m.pages = {}       ' tab key -> next page number
    m.tasks = {}
    m.tabIndex = 0
    m.area = "tabs"

    m.grid.observeField("itemSelected", "onItemSelected")
    m.grid.observeField("itemFocused", "onItemFocused")
    m.global.observeField("loggedIn", "onLoginChanged")
    m.top.observeField("focusedChild", "onFocusChanged")

    applyTheme()
    m.global.observeField("theme", "applyTheme")
    onLoginChanged()
    selectTab(0)
end sub

sub buildTabs()
    m.tabNodes = []
    group = m.top.findNode("tabs")
    x = 0
    for each t in m.tabsDef
        g = group.createChild("Group")
        g.translation = [x, 0]
        pill = g.createChild("Poster")
        pill.width = 120
        pill.height = 60
        pill.visible = false
        lbl = g.createChild("Label")
        lbl.text = t.name
        lbl.font = cjkFont(34)
        lbl.width = 120
        lbl.height = 60
        lbl.horizAlign = "center"
        lbl.vertAlign = "center"
        bar = g.createChild("Rectangle")
        bar.width = 30
        bar.height = 5
        bar.translation = [45, 64]
        bar.visible = false
        m.tabNodes.Push({ pill: pill, label: lbl, bar: bar })
        x = x + 136
    end for
end sub

' Live: the settings screen changes the theme while this screen stays in the stack.
sub applyTheme()
    m.top.findNode("brand").color = accent()
    m.spinner.poster.uri = themed("spinner")
    for each n in m.tabNodes
        n.pill.uri = themed("pill")
        n.bar.color = accent()
    end for
    if m.global.loggedIn then m.account.color = accent()
    paintTabs()
end sub

sub paintTabs()
    for i = 0 to m.tabNodes.Count() - 1
        n = m.tabNodes[i]
        selected = (i = m.tabIndex)
        onBar = selected and m.area = "tabs"
        n.pill.visible = onBar
        n.bar.visible = selected and not onBar
        if onBar then
            n.label.color = onAccent()
        else if selected then
            n.label.color = accent()
        else
            n.label.color = "0xB4B4C0FF"
        end if
    end for
end sub

function currentKey() as String
    return m.tabsDef[m.tabIndex].key
end function

sub selectTab(i as Integer)
    m.tabIndex = i
    paintTabs()
    key = currentKey()
    m.hint.visible = (key = "history" and m.global.loggedIn)
    ' these tabs open their own screen; say so instead of leaving an old grid or spinner up
    if key = "search" then
        showMessage("按 OK 搜索视频")
        return
    else if key = "me" then
        if m.global.loggedIn then
            showMessage("按 OK 管理账号")
        else
            showMessage("按 OK 扫码登录，登录后可看 1080P")
        end if
        return
    else if key = "settings" then
        showMessage("按 OK 打开设置（主题色、弹幕）")
        return
    end if
    ' history moves as you watch, so it is fetched fresh every time
    if key <> "history" and m.cache.DoesExist(key) then
        showContent(m.cache[key])
    else
        load(key, false)
    end if
end sub

sub load(key as String, more as Boolean)
    if key = "history" and not m.global.loggedIn then
        showMessage("登录后可以在这里看到你的观看历史" + Chr(10) + "按 OK 去扫码登录")
        return
    end if
    if m.tasks.DoesExist(key) then return
    page = 1
    if more and m.pages.DoesExist(key) then page = m.pages[key]
    params = { tab: key, page: page }
    if key = "history" then
        if not more then
            m.historyCursor = {}
            m.historyEnd = false
        else if m.historyEnd then
            return
        else
            params.max = strOf(m.historyCursor.max)
            params.view_at = strOf(m.historyCursor.view_at)
            params.business = strOf(m.historyCursor.business)
        end if
    end if
    if not more then showLoading()
    m.tasks[key] = api("home", params, "onLoaded", key)
    m.tasks[key].addFields({ more: more })
end sub

sub onLoaded(event as Object)
    task = event.getRoSGNode()
    key = task.tag
    m.tasks.Delete(key)
    res = event.getData()
    if not res.ok then
        if key = currentKey() and not task.more then showMessage("加载失败：" + res.error + Chr(10) + "按 OK 重试")
        return
    end if
    items = res.data.items
    if key = "history" then
        if type(res.data.cursor) = "roAssociativeArray" then m.historyCursor = res.data.cursor
        m.historyEnd = boolOf(res.data.last)
    end if
    if task.more and m.cache.DoesExist(key) then
        cardsToContent(items, m.cache[key])
    else
        content = cardsToContent(items, CreateObject("roSGNode", "ContentNode"))
        m.cache[key] = content
        if key = currentKey() then showContent(content)
    end if
    m.pages[key] = intOf(m.pages[key]) + 1
    if not task.more then m.pages[key] = 2
end sub

sub showContent(content as Object)
    m.spinner.visible = false
    m.spinner.control = "stop"
    if content.getChildCount() = 0 then
        showMessage("这里还没有内容")
        return
    end if
    m.message.visible = false
    m.grid.visible = true
    m.grid.content = content
    m.grid.jumpToItem = 0
end sub

sub showLoading()
    m.grid.visible = false
    m.message.visible = false
    m.spinner.visible = true
    m.spinner.control = "start"
end sub

sub showMessage(text as String)
    m.spinner.visible = false
    m.spinner.control = "stop"
    m.grid.visible = false
    m.message.text = text
    m.message.visible = true
    if m.area = "grid" then focusTabs()
end sub

sub refresh()
    key = currentKey()
    if key = "search" or key = "me" or key = "settings" then return
    m.cache.Delete(key)
    load(key, false)
end sub

sub onItemFocused()
    key = currentKey()
    if key <> "rcmd" and key <> "popular" and key <> "history" then return
    content = m.grid.content
    if content = invalid then return
    if m.grid.itemFocused >= content.getChildCount() - 8 then load(key, true)
end sub

sub onItemSelected()
    item = m.grid.content.getChild(m.grid.itemSelected)
    if item = invalid then return
    navigate({ action: "detail", bvid: item.bvid })
end sub

sub onLoginChanged()
    if m.global.loggedIn then
        m.account.text = "已登录  ·  1080P"
        m.account.color = accent()
    else
        m.account.text = "未登录  ·  最高 720P"
        m.account.color = "0x8E8E9EFF"
    end if
    if m.hint <> invalid then m.hint.visible = (currentKey() = "history" and m.global.loggedIn)
    ' the feed and history change with the account
    m.cache.Delete("rcmd")
    m.cache.Delete("history")
    key = currentKey()
    if m.tabNodes <> invalid and (key = "rcmd" or key = "history") then load(key, false)
end sub

' Focus goes to the tab bar node itself: setFocus on this screen would be a no-op
' while the grid (a descendant) still holds focus.
sub focusTabs()
    m.area = "tabs"
    paintTabs()
    m.tabsGroup.setFocus(true)
end sub

sub focusGrid()
    if not m.grid.visible or m.grid.content = invalid then return
    if m.grid.content.getChildCount() = 0 then return
    m.area = "grid"
    paintTabs()
    m.grid.setFocus(true)
end sub

sub onFocusChanged()
    if not m.top.hasFocus() then return
    if m.area = "grid" then
        m.grid.setFocus(true)
    else
        m.tabsGroup.setFocus(true)
    end if
end sub

' ---------- history actions (* on a history card) ----------

sub openHistoryMenu()
    item = m.grid.content.getChild(m.grid.itemFocused)
    if item = invalid then return
    m.menuItem = item
    m.menuMode = "item"
    m.menu.title = item.title
    m.menu.message = ""
    m.menu.options = ["从观看历史中删除", "清空全部观看历史…", "取消"]
    m.menu.visible = true
    m.menu.setFocus(true)
end sub

sub onMenuChosen()
    i = m.menu.chosen
    if m.menuMode = "item" then
        if i = 0 then
            closeMenu()
            m.deleteTask = api("historydelete", { aid: m.menuItem.aid }, "onHistoryDeleted")
        else if i = 1 then
            ' it wipes the account on every device, so ask once more
            m.menuMode = "clear"
            m.menu.title = "清空全部观看历史？"
            m.menu.message = "会删除这个 B 站账号在所有设备上的观看历史，无法恢复。"
            m.menu.options = ["取消", "确定清空"]   ' a stray OK lands on 取消
        else
            closeMenu()
        end if
    else
        closeMenu()
        if i = 1 then m.clearTask = api("historyclear", invalid, "onHistoryCleared")
    end if
end sub

sub closeMenu()
    m.menu.visible = false
    if m.grid.visible and m.grid.content <> invalid then
        if m.grid.content.getChildCount() > 0 then
            m.area = "grid"
            paintTabs()
            m.grid.setFocus(true)
            return
        end if
    end if
    focusTabs()
end sub

sub onHistoryDeleted(event as Object)
    res = event.getData()
    if not res.ok then
        toast("删除失败：" + res.error)
        return
    end if
    forgetProgress(m.menuItem.bvid)
    content = m.grid.content
    if content <> invalid then content.removeChild(m.menuItem)
    toast("已从观看历史中删除")
    if content = invalid or content.getChildCount() = 0 then showMessage("这里还没有内容")
end sub

sub onHistoryCleared(event as Object)
    res = event.getData()
    if not res.ok then
        toast("清空失败：" + res.error)
        return
    end if
    forgetAllProgress()
    m.cache.Delete("history")
    m.historyEnd = true
    toast("观看历史已清空")
    showMessage("观看历史已清空")
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "options" then
        if currentKey() = "history" and m.area = "grid" and m.global.loggedIn then
            openHistoryMenu()
        else
            refresh()
        end if
        return true
    end if

    if m.area = "tabs" then
        if key = "left" and m.tabIndex > 0 then
            selectTab(m.tabIndex - 1)
            return true
        else if key = "right" and m.tabIndex < m.tabsDef.Count() - 1 then
            selectTab(m.tabIndex + 1)
            return true
        else if key = "down" then
            focusGrid()
            return true
        else if key = "OK" then
            k = currentKey()
            if k = "search" then
                navigate({ action: "search" })
            else if k = "settings" then
                navigate({ action: "settings" })
            else if k = "me" or (k = "history" and not m.global.loggedIn) then
                navigate({ action: "login" })
            else if m.message.visible then
                refresh()
            else
                focusGrid()
            end if
            return true
        end if
        return false
    end if

    ' grid: whatever the grid did not consume
    if key = "up" or key = "back" then
        focusTabs()
        return true
    end if
    return false
end function
