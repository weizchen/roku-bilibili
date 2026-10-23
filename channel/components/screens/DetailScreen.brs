sub init()
    m.info = m.top.findNode("info")
    m.backdrop = m.top.findNode("backdrop")
    m.title = m.top.findNode("title")
    m.meta = m.top.findNode("meta")
    m.stats = m.top.findNode("stats")
    m.desc = m.top.findNode("desc")
    m.buttons = m.top.findNode("buttons")
    m.cover = m.top.findNode("cover")
    m.partsBox = m.top.findNode("partsBox")
    m.parts = m.top.findNode("parts")
    m.related = m.top.findNode("related")
    m.spinner = m.top.findNode("spinner")
    m.message = m.top.findNode("message")

    m.title.font = cjkFont(50)
    m.meta.font = cjkFont(28)
    m.stats.font = cjkFont(26)
    m.desc.font = cjkFont(26)
    m.message.font = cjkFont(32)
    m.top.findNode("partsTitle").font = cjkFont(32)
    m.buttons.textFont = cjkFont(32)
    m.buttons.focusedTextFont = cjkFont(32)
    m.parts.font = cjkFont(26)
    m.parts.focusedFont = cjkFont(26)
    m.related.rowLabelFont = cjkFont(30)
    m.spinner.poster.uri = "pkg:/images/spinner.png"
    m.spinner.control = "start"

    m.video = invalid
    m.remote = invalid
    m.autoplayPending = false
    m.focusNode = m.buttons
    m.buttons.observeField("buttonSelected", "onButton")
    m.parts.observeField("itemSelected", "onPart")
    m.related.observeField("rowItemSelected", "onRelated")
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

sub load()
    m.videoTask = api("video", { bvid: m.top.bvid }, "onVideo")
    m.relatedTask = api("related", { bvid: m.top.bvid }, "onRelatedLoaded")
end sub

sub onVideo(event as Object)
    m.spinner.control = "stop"
    m.spinner.visible = false
    res = event.getData()
    if not res.ok then
        m.message.text = "视频加载失败：" + res.error
        m.message.visible = true
        return
    end if
    v = res.data
    m.video = v
    m.title.text = strOf(v.title)
    meta = strOf(v.up)
    if strOf(v.date_text) <> "" then
        meta = meta + "    " + strOf(v.date_text) + " 发布"
        ' past a month ago() falls back to a date, which would only repeat itself
        if Instr(1, strOf(v.ago_text), "-") = 0 then meta = meta + "（" + strOf(v.ago_text) + "）"
    end if
    m.meta.text = meta + "    " + fmtTime(intOf(v.duration))
    m.stats.text = strOf(v.view_text) + " 播放    " + strOf(v.danmaku_text) + " 弹幕    " + strOf(v.like_text) + " 点赞"
    m.desc.text = strOf(v.desc)
    layoutText()
    m.backdrop.uri = strOf(v.poster)
    m.cover.uri = strOf(v.poster)

    m.pages = v.pages
    if m.pages.Count() > 1 then
        m.cover.visible = false
        m.partsBox.visible = true
        m.top.findNode("partsTitle").text = "选集（" + m.pages.Count().ToStr() + "P）"
        content = CreateObject("roSGNode", "ContentNode")
        for each p in m.pages
            item = content.createChild("ContentNode")
            item.title = "  P" + strOf(p.page) + "  " + strOf(p.part) + "    " + strOf(p.duration_text)
        end for
        m.parts.content = content
    end if

    m.saved = loadProgress(m.top.bvid)
    paintResume()
    m.info.visible = true
    setFocusNode(m.buttons)

    ' nothing saved on this TV: ask the account where it left off
    askedAccount = false
    if m.saved = invalid and m.global.loggedIn then
        m.progressTask = api("progress", { aid: strOf(v.aid), cid: strOf(v.cid), bvid: m.top.bvid }, "onAccountProgress")
        askedAccount = true
    end if
    if m.top.autoplay then
        m.top.autoplay = false
        if askedAccount then
            m.autoplayPending = true
        else
            onButton()
        end if
    end if
end sub

sub onAccountProgress(event as Object)
    res = event.getData()
    if res.ok and loadProgress(m.top.bvid) = invalid then
        secs = intOf(res.data.seconds)
        cid = strOf(res.data.cid)
        index = 0
        for i = 0 to m.pages.Count() - 1
            if strOf(m.pages[i].cid) = cid then index = i
        end for
        dur = intOf(m.pages[index].duration)
        if secs >= 10 and (dur <= 0 or secs < dur - 20) then
            m.remote = { b: m.top.bvid, i: index, p: secs, d: dur }
            m.saved = m.remote
            paintResume()
            ' replacing the buttons drops the focused one; hand focus back
            if m.top.visible then m.focusNode.setFocus(true)
        end if
    end if
    if m.autoplayPending then
        m.autoplayPending = false
        onButton()
    end if
end sub

sub paintResume()
    if m.saved = invalid then
        m.buttons.buttons = ["▶  播放"]
        return
    end if
    resume = "▶  继续 " + fmtTime(intOf(m.saved.p))
    if m.pages.Count() > 1 then resume = "▶  继续 P" + (intOf(m.saved.i) + 1).ToStr() + " " + fmtTime(intOf(m.saved.p))
    m.buttons.buttons = [resume, "从头播放"]
    if m.pages.Count() > 1 then m.parts.jumpToItem = intOf(m.saved.i)
end sub

' stack meta and description under however many lines the title took
sub layoutText()
    metaY = 86 + Int(m.title.boundingRect().height) + 18
    m.meta.translation = [96, metaY]
    m.stats.translation = [96, metaY + 46]
    descY = metaY + 100
    m.desc.translation = [96, descY]
    lines = Int((496 - descY) / 45)
    if lines < 1 then lines = 1
    m.desc.maxLines = lines
    m.desc.height = 0
end sub

sub onRelatedLoaded(event as Object)
    res = event.getData()
    if not res.ok then return
    root = CreateObject("roSGNode", "ContentNode")
    row = root.createChild("ContentNode")
    row.title = "相关推荐"
    cardsToContent(res.data.items, row)
    if row.getChildCount() > 0 then m.related.content = root
end sub

sub onButton()
    if m.video = invalid then return
    if m.saved <> invalid and m.buttons.buttonSelected = 0 then
        play(intOf(m.saved.i), intOf(m.saved.p))
    else
        play(0, 0)
    end if
end sub

sub onPart()
    start = 0
    if m.saved <> invalid and intOf(m.saved.i) = m.parts.itemSelected then start = intOf(m.saved.p)
    play(m.parts.itemSelected, start)
end sub

sub onRelated()
    sel = m.related.rowItemSelected
    item = m.related.content.getChild(sel[0]).getChild(sel[1])
    if item <> invalid then navigate({ action: "detail", bvid: item.bvid })
end sub

sub play(index as Integer, startAt as Integer)
    if index >= m.pages.Count() then index = 0
    m.remote = invalid   ' from here on this TV's own bookmark is the newer one
    navigate({
        action: "play"
        bvid: m.top.bvid
        aid: strOf(m.video.aid)
        title: strOf(m.video.title)
        up: strOf(m.video.up)
        pages: m.pages
        index: index
        startAt: startAt
    })
end sub

sub setFocusNode(node as Object)
    m.focusNode = node
    node.setFocus(true)
end sub

' coming back from the player: progress may have moved
sub onFocusChanged()
    if not m.top.hasFocus() then return
    if m.video <> invalid then refreshResume()
    m.focusNode.setFocus(true)
end sub

sub refreshResume()
    m.saved = loadProgress(m.top.bvid)
    if m.saved = invalid then m.saved = m.remote
    paintResume()
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press or m.video = invalid then return false
    hasRelated = m.related.content <> invalid
    hasParts = m.partsBox.visible
    if m.buttons.isInFocusChain() then
        if key = "down" and hasRelated then
            setFocusNode(m.related)
            return true
        else if key = "right" and hasParts then
            setFocusNode(m.parts)
            return true
        end if
    else if m.parts.isInFocusChain() then
        if key = "left" then
            setFocusNode(m.buttons)
            return true
        else if key = "down" and hasRelated then
            setFocusNode(m.related)
            return true
        end if
    else if m.related.isInFocusChain() then
        if key = "up" then
            setFocusNode(m.buttons)
            return true
        end if
    end if
    return false
end function
