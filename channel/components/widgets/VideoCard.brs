sub init()
    m.ring = m.top.findNode("ring")
    m.frame = m.top.findNode("frame")
    m.poster = m.top.findNode("poster")
    m.badge = m.top.findNode("badge")
    m.duration = m.top.findNode("duration")
    m.title = m.top.findNode("title")
    m.meta = m.top.findNode("meta")
    m.scrim = m.top.findNode("scrim")
    m.stats = m.top.findNode("stats")
    m.progressBg = m.top.findNode("progressBg")
    m.progressBar = m.top.findNode("progressBar")
    m.w = 0
    applyTheme()
    m.global.observeField("theme", "applyTheme")
    layout()
end sub

sub applyTheme()
    m.ring.uri = themed("focus")
    m.progressBar.color = accent()
end sub

sub layout()
    w = Int(m.top.width)
    if w <= 0 then w = 414
    if w = m.w then return
    m.w = w
    h = Int(w * 9 / 16)
    m.h = h
    m.ring.translation = [-8, -8]
    m.ring.width = w + 16
    m.ring.height = h + 16
    m.frame.width = w
    m.frame.height = h
    m.poster.width = w
    m.poster.height = h
    m.poster.loadWidth = w
    m.poster.loadHeight = h

    titleSize = 26
    metaSize = 22
    if w < 400 then
        titleSize = 23
        metaSize = 20
    end if
    lineH = titleSize + 10
    m.title.font = cjkFont(titleSize)
    m.title.width = w
    m.title.translation = [0, h + 12]
    m.meta.font = cjkFont(metaSize)
    m.meta.width = w
    m.meta.translation = [0, h + 18 + lineH * 2]
    m.scrim.width = w
    m.scrim.height = 64
    m.scrim.translation = [0, h - 64]
    m.stats.font = cjkFont(metaSize)
    m.stats.translation = [12, h - metaSize - 16]
    m.progressBg.translation = [0, h - 6]
    m.progressBg.width = w
    m.progressBg.height = 6
    m.progressBar.translation = [0, h - 6]
    m.progressBar.height = 6
    placeBadge()
end sub

sub onContent()
    c = m.top.itemContent
    if c = invalid then return
    m.poster.uri = c.HDPosterUrl
    m.title.text = c.title
    ' history cards say how far you got; the others say when it came out
    meta = c.up
    extra = c.dateText
    if c.history then extra = c.viewText
    if extra <> "" then
        if meta <> "" then meta = meta + "  ·  "
        meta = meta + extra
    end if
    m.meta.text = meta
    showStats = not c.history and c.viewText <> ""
    m.stats.text = "▶ " + c.viewText
    m.stats.visible = showStats
    m.scrim.visible = showStats
    m.duration.text = c.durationText
    placeBadge()

    if c.progress > 0 and c.seconds > 0 then
        pct = c.progress / c.seconds
        if pct > 1 then pct = 1
        m.progressBar.width = Int(m.w * pct)
        m.progressBg.visible = true
        m.progressBar.visible = true
    else
        m.progressBg.visible = false
        m.progressBar.visible = false
    end if
end sub

sub placeBadge()
    if m.duration.text = "" then
        m.badge.visible = false
        return
    end if
    r = m.duration.boundingRect()
    bw = r.width + 18
    bh = r.height + 6
    m.badge.width = bw
    m.badge.height = bh
    m.badge.translation = [m.w - bw - 10, m.h - bh - 12]
    m.duration.translation = [m.w - bw - 10 + 9, m.h - bh - 12 + 3]
    m.badge.visible = true
end sub

sub onFocus()
    p = 0.0
    if m.top.gridHasFocus or m.top.rowListHasFocus then p = m.top.focusPercent
    m.ring.opacity = p
    if p > 0.5 then
        m.title.color = "0xFFFFFFFF"
    else
        m.title.color = "0xD2D2DCFF"
    end if
end sub
