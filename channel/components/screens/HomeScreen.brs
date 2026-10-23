' Home: tab bar plus the tab's content. Focus lives in one of four areas:
' "tabs" (the bar), "grid" (video cards), "folders" (我的 favourites) or
' "settings" (the settings rows).

sub init()
    m.tabsDef = [
        { key: "rcmd", name: "推荐" }
        { key: "popular", name: "热门" }
        { key: "rank", name: "排行" }
        { key: "live", name: "直播" }
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
    m.hint = m.top.findNode("hint")
    m.login = m.top.findNode("login")
    m.settings = m.top.findNode("settings")
    m.menu = m.top.findNode("menu")
    m.meBox = m.top.findNode("meBox")
    m.folders = m.top.findNode("folders")
    m.avatar = m.top.findNode("avatar")
    m.uname = m.top.findNode("uname")
    m.badges = m.top.findNode("badges")
    m.meStats = m.top.findNode("meStats")
    m.meHint = m.top.findNode("meHint")
    m.favTitle = m.top.findNode("favTitle")
    m.uname.font = cjkFont(46)
    m.badges.font = cjkFont(28)
    m.meStats.font = cjkFont(26)
    m.meHint.font = cjkFont(24)
    m.meHint.text = "按 * 刷新或退出登录"
    m.favTitle.font = cjkFont(32)
    m.top.findNode("brand").font = cjkFont(40)
    m.account.font = cjkFont(26)
    m.hint.font = cjkFont(22)
    m.message.font = cjkFont(32)
    m.menu.observeField("chosen", "onMenuChosen")
    m.menu.observeField("closed", "closeMenu")

    buildTabs()
    m.cache = {}       ' tab key -> ContentNode
    m.pages = {}       ' tab key -> next page number
    m.tasks = {}
    m.historyCursor = {}
    m.historyEnd = false
    m.meInfo = invalid       ' account card data once loaded
    m.favFolders = invalid   ' [{id, title, count, cover}] once loaded
    m.tabIndex = 0
    m.area = "tabs"

    m.grid.observeField("itemSelected", "onItemSelected")
    m.grid.observeField("itemFocused", "onItemFocused")
    m.folders.observeField("itemSelected", "onFolderSelected")
    m.global.observeField("loggedIn", "onLoginChanged")
    m.global.observeField("uname", "paintAccount")
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

' Live: the settings rows change the theme while this screen stays up.
sub applyTheme()
    m.top.findNode("brand").color = accent()
    m.spinner.poster.uri = themed("spinner")
    for each n in m.tabNodes
        n.pill.uri = themed("pill")
        n.bar.color = accent()
    end for
    m.badges.color = accent()
    paintAccount()
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

sub paintAccount()
    if m.global.loggedIn then
        who = m.global.uname
        if who = "" then who = "已登录"
        m.account.text = who + "  ·  1080P"
        m.account.color = accent()
    else
        m.account.text = "未登录  ·  最高 720P"
        m.account.color = "0x8E8E9EFF"
    end if
end sub

' the small line under the account: what * does on this tab
sub updateHint()
    key = currentKey()
    if key = "history" and m.global.loggedIn then
        m.hint.text = "按 * 键删除历史记录"
        m.hint.visible = true
    else
        m.hint.visible = false
    end if
end sub

sub onResume()
    r = m.top.resume
    for i = 0 to m.tabsDef.Count() - 1
        if m.tabsDef[i].key = strOf(r.tab) then selectTab(i)
    end for
    if currentKey() = "settings" and not isNil(r.row) then focusSettings(intOf(r.row))
end sub

function tabIndexOf(key as String) as Integer
    for i = 0 to m.tabsDef.Count() - 1
        if m.tabsDef[i].key = key then return i
    end for
    return 0
end function

function currentKey() as String
    return m.tabsDef[m.tabIndex].key
end function

sub selectTab(i as Integer)
    m.tabIndex = i
    paintTabs()
    key = currentKey()
    m.login.active = false
    m.login.visible = false
    m.settings.visible = false
    m.meBox.visible = false
    updateHint()
    if key = "search" then
        showMessage("按 OK 搜索视频")
    else if key = "settings" then
        hideContent()
        m.settings.visible = true
    else if key = "me" then
        if m.global.loggedIn then
            showMe()
        else
            hideContent()
            m.login.visible = true
            m.login.active = true
        end if
    else if key <> "history" and key <> "live" and m.cache.DoesExist(key) then
        showContent(m.cache[key])
    else
        ' history moves as you watch and live rooms come and go, so both are fetched fresh
        load(key, false)
    end if
end sub

' ---------- loading ----------

sub load(key as String, more as Boolean)
    if key = "history" and not m.global.loggedIn then
        showMessage("登录后可以在这里看到你的观看历史" + Chr(10) + "按 OK 去「我的」扫码登录")
        return
    end if
    if m.tasks.DoesExist(key) then return
    page = 1
    if more and m.pages.DoesExist(key) then page = m.pages[key]
    op = "home"
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
    m.tasks[key] = api(op, params, "onLoaded", key)
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

' ---------- 我的: account card + favourite folders ----------

sub showMe()
    hideContent()
    m.meBox.visible = true
    if m.meInfo = invalid then
        m.uname.text = "正在加载…"
        m.badges.text = ""
        m.meStats.text = ""
        if m.meTask = invalid or m.meTask.state <> "run" then m.meTask = api("me", invalid, "onMe")
    end if
    if m.favFolders = invalid then
        m.favTitle.text = "我的收藏夹"
        m.folders.content = invalid
        if m.folderTask = invalid or m.folderTask.state <> "run" then m.folderTask = api("favfolders", invalid, "onFolders")
    end if
end sub

sub onMe(event as Object)
    res = event.getData()
    if not res.ok then
        m.uname.text = "账号信息加载失败"
        m.meStats.text = res.error
        return
    end if
    d = res.data
    m.meInfo = d
    m.avatar.uri = strOf(d.face)
    m.uname.text = strOf(d.uname)
    badges = "LV" + strOf(d.level)
    if strOf(d.vip) <> "" then badges = badges + "    " + strOf(d.vip)
    m.badges.text = badges
    m.meStats.text = "关注 " + strOf(d.following) + "      粉丝 " + strOf(d.follower) + "      硬币 " + strOf(d.coins)
end sub

sub onFolders(event as Object)
    res = event.getData()
    if not res.ok then
        m.favTitle.text = "收藏夹加载失败：" + res.error + "（按 * 刷新）"
        return
    end if
    m.favFolders = res.data.folders
    content = CreateObject("roSGNode", "ContentNode")
    missing = []
    for each f in m.favFolders
        node = content.createChild("ContentNode")
        node.addFields({ folderId: f.id, folderCount: f.count, up: "", viewText: "", statsText: "", dateText: intOf(f.count).ToStr() + " 个视频", durationText: "", seconds: 0, progress: 0, history: false, live: false, roomid: "" })
        node.title = f.title
        if f.cover <> "" then
            node.HDPosterUrl = f.cover
        else
            node.HDPosterUrl = "pkg:/images/placeholder.png"
            if f.count > 0 then missing.Push(f.id)
        end if
    end for
    m.folders.content = content
    m.favTitle.text = "我的收藏夹（" + m.favFolders.Count().ToStr() + "）"
    if missing.Count() > 0 then m.coverTask = api("favcovers", { ids: missing }, "onFolderCovers")
end sub

sub onFolderCovers(event as Object)
    res = event.getData()
    if not res.ok or m.folders.content = invalid then return
    covers = res.data.covers
    content = m.folders.content
    for i = 0 to content.getChildCount() - 1
        node = content.getChild(i)
        url = covers[node.folderId]
        if not isNil(url) then node.HDPosterUrl = url
    end for
end sub

sub onFolderSelected()
    item = m.folders.content.getChild(m.folders.itemSelected)
    if item = invalid then return
    navigate({ action: "favorites", id: item.folderId, title: item.title, count: item.folderCount })
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
    hideContent()
    m.message.text = text
    m.message.visible = true
end sub

sub hideContent()
    m.spinner.visible = false
    m.spinner.control = "stop"
    m.grid.visible = false
    m.message.visible = false
    if m.area = "grid" then focusTabs()
end sub

sub refresh()
    key = currentKey()
    if key = "search" or key = "settings" then return
    if key = "me" then
        if not m.global.loggedIn then return
        m.meInfo = invalid
        m.favFolders = invalid
        if m.area = "folders" then focusTabs()
        showMe()
        return
    end if
    m.cache.Delete(key)
    load(key, false)
end sub

sub onItemFocused()
    key = currentKey()
    if key <> "rcmd" and key <> "popular" and key <> "history" and key <> "live" then return
    content = m.grid.content
    if content = invalid then return
    if m.grid.itemFocused >= content.getChildCount() - 8 then load(key, true)
end sub

sub onItemSelected()
    item = m.grid.content.getChild(m.grid.itemSelected)
    if item = invalid then return
    if item.live then
        navigate({ action: "live", roomid: item.roomid, title: item.title, up: item.up })
    else
        navigate({ action: "detail", bvid: item.bvid })
    end if
end sub

sub onLoginChanged()
    paintAccount()
    ' the feed, history and favourites all belong to the account
    m.cache.Delete("rcmd")
    m.cache.Delete("history")
    m.meInfo = invalid
    m.favFolders = invalid
    if m.tabNodes = invalid then return
    key = currentKey()
    if key = "rcmd" or key = "history" or key = "live" or key = "me" then selectTab(m.tabIndex)
end sub

' ---------- focus ----------

' Focus goes to the tab bar node itself: setFocus on this screen would be a no-op
' while the grid (a descendant) still holds focus.
sub focusTabs()
    m.area = "tabs"
    m.settings.active = false
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

sub focusFolders()
    if m.folders.content = invalid then return
    if m.folders.content.getChildCount() = 0 then return
    m.area = "folders"
    paintTabs()
    m.folders.setFocus(true)
end sub

sub focusSettings(row = -1 as Integer)
    m.area = "settings"
    paintTabs()
    if row >= 0 then m.settings.row = row
    m.settings.active = true
    m.settings.setFocus(true)
end sub

sub onFocusChanged()
    if not m.top.hasFocus() then return
    if m.area = "grid" then
        m.grid.setFocus(true)
    else if m.area = "folders" then
        m.folders.setFocus(true)
    else if m.area = "settings" then
        m.settings.setFocus(true)
    else
        m.tabsGroup.setFocus(true)
    end if
end sub

' ---------- * menus: history card, 我的 ----------

sub openMenu(title as String, message as String, options as Object, mode as String)
    m.menuMode = mode
    m.menu.title = title
    m.menu.message = message
    m.menu.options = options
    m.menu.visible = true
    m.menu.setFocus(true)
end sub

sub openHistoryMenu()
    item = m.grid.content.getChild(m.grid.itemFocused)
    if item = invalid then return
    m.menuItem = item
    openMenu(item.title, "", ["从观看历史中删除", "清空全部观看历史…", "取消"], "item")
end sub

sub openMeMenu()
    openMenu("我的", "", ["刷新账号和收藏夹", "退出登录…", "取消"], "me")
end sub

sub onMenuChosen()
    i = m.menu.chosen
    if m.menuMode = "item" then
        if i = 0 then
            closeMenu()
            m.deleteTask = api("historydelete", { aid: m.menuItem.aid }, "onHistoryDeleted")
        else if i = 1 then
            ' it wipes the account on every device, so ask once more
            openMenu("清空全部观看历史？", "会删除这个 B 站账号在所有设备上的观看历史，无法恢复。", ["取消", "确定清空"], "clear")   ' a stray OK lands on 取消
        else
            closeMenu()
        end if
    else if m.menuMode = "clear" then
        closeMenu()
        if i = 1 then m.clearTask = api("historyclear", invalid, "onHistoryCleared")
    else if m.menuMode = "me" then
        if i = 0 then
            closeMenu()
            refresh()
        else if i = 1 then
            openMenu("退出登录？", "退出后最高 720P，历史和收藏要重新扫码登录才能看。", ["取消", "退出登录"], "logout")
        else
            closeMenu()
        end if
    else if m.menuMode = "logout" then
        closeMenu()
        if i = 1 then m.logoutTask = api("logout", invalid, "onLoggedOut")
    end if
end sub

sub closeMenu()
    m.menu.visible = false
    if m.area = "folders" and m.meBox.visible then
        paintTabs()
        m.folders.setFocus(true)
        return
    end if
    if m.grid.visible and m.grid.content <> invalid then
        if m.grid.content.getChildCount() > 0 and m.area = "grid" then
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

sub onLoggedOut(event as Object)
    m.global.uname = ""
    m.global.loggedIn = false
    toast("已退出登录")
end sub

' ---------- keys ----------

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    k = currentKey()
    if key = "options" then
        if k = "history" and m.area = "grid" and m.global.loggedIn then
            openHistoryMenu()
        else if k = "me" and m.global.loggedIn then
            openMeMenu()
        else if k <> "settings" then
            refresh()
        end if
        return true
    end if

    if m.area = "settings" then
        ' whatever the rows did not use: up off the first row, back
        if key = "up" or key = "back" then
            focusTabs()
            return true
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
            if k = "settings" then
                focusSettings()
            else if k = "me" and m.global.loggedIn then
                focusFolders()
            else
                focusGrid()
            end if
            return true
        else if key = "OK" then
            if k = "search" then
                navigate({ action: "search" })
            else if k = "settings" then
                focusSettings()
            else if k = "me" and not m.global.loggedIn then
                m.login.refresh = true   ' only renews an expired or failed code
            else if k = "me" then
                focusFolders()
            else if k = "history" and not m.global.loggedIn then
                selectTab(tabIndexOf("me"))   ' 我的 has the QR code
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
