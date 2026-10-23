sub init()
    m.alphas = [0.2, 0.4, 0.6, 0.8, 1.0]
    m.themeList = themes()
    names = []
    for each t in m.themeList
        names.Push(t.name)
    end for
    m.fontList = fonts()
    fontNames = []
    for each f in m.fontList
        fontNames.Push(f.name)
    end for
    m.rowsDef = [
        { name: "主题色", labels: names }
        { name: "字体", labels: fontNames }
        { name: "弹幕默认", labels: ["关", "开"] }
        { name: "弹幕不透明度", labels: ["20%", "40%", "60%", "80%", "100%"] }
    ]

    m.rows = []
    group = m.top.findNode("rows")
    for i = 0 to m.rowsDef.Count() - 1
        g = group.createChild("Group")
        g.translation = [0, i * 104]
        chip = g.createChild("Poster")
        chip.width = 960
        chip.height = 88
        name = g.createChild("Label")
        name.text = m.rowsDef[i].name
        name.translation = [36, 0]
        name.height = 88
        name.vertAlign = "center"
        swatch = g.createChild("Rectangle")
        swatch.width = 30
        swatch.height = 30
        swatch.translation = [600, 29]
        swatch.visible = (i = 0)
        value = g.createChild("Label")
        value.translation = [640, 0]
        value.width = 290
        value.height = 88
        value.horizAlign = "right"
        value.vertAlign = "center"
        m.rows.Push({ chip: chip, name: name, swatch: swatch, value: value })
    end for
    m.sel = 0
    applyFonts()
    paint()
end sub

sub applyFonts()
    m.top.findNode("heading").font = cjkFont(52)
    m.top.findNode("hint").font = cjkFont(26)
    m.top.findNode("previewBrand").font = cjkFont(48)
    m.top.findNode("previewPillText").font = cjkFont(32)
    m.top.findNode("previewText").font = cjkFont(26)
    for each r in m.rows
        r.name.font = cjkFont(34)
        r.value.font = cjkFont(34)
    end for
end sub

function valueIndex(row as Integer) as Integer
    if row = 0 then
        for i = 0 to m.themeList.Count() - 1
            if m.themeList[i].key = m.global.theme.key then return i
        end for
        return 0
    else if row = 1 then
        for i = 0 to m.fontList.Count() - 1
            if m.fontList[i].key = m.global.font.key then return i
        end for
        return 0
    else if row = 2 then
        if loadSetting("dm_on", "1") = "1" then return 1
        return 0
    end if
    alpha = Val(loadSetting("dm_alpha", "0.8"))
    best = 3
    for i = 0 to m.alphas.Count() - 1
        if Abs(m.alphas[i] - alpha) < 0.05 then best = i
    end for
    return best
end function

sub change(delta as Integer, wrap as Boolean)
    count = m.rowsDef[m.sel].labels.Count()
    i = valueIndex(m.sel) + delta
    if wrap then
        i = (i + count) mod count
    else if i < 0 or i >= count then
        return
    end if
    if m.sel = 0 then
        ' the home screen and its cards repaint themselves off this global
        m.global.theme = m.themeList[i]
        saveSetting("theme", m.themeList[i].key)
    else if m.sel = 1 then
        ' the rest of the app picks the new font up as screens are rebuilt
        m.global.font = m.fontList[i]
        saveSetting("font", m.fontList[i].key)
        applyFonts()
    else if m.sel = 2 then
        if i = 1 then
            saveSetting("dm_on", "1")
        else
            saveSetting("dm_on", "0")
        end if
    else
        saveSetting("dm_alpha", Str(m.alphas[i]).Trim())
    end if
    paint()
end sub

sub paint()
    for i = 0 to m.rows.Count() - 1
        r = m.rows[i]
        focused = (i = m.sel)
        r.chip.uri = themed("chip")
        r.chip.visible = focused
        r.swatch.color = accent()
        r.value.text = "‹  " + m.rowsDef[i].labels[valueIndex(i)] + "  ›"
        if focused then
            r.name.color = onAccent()
            r.value.color = onAccent()
        else
            r.name.color = "0xD2D2DCFF"
            r.value.color = "0xD2D2DCFF"
        end if
    end for
    m.top.findNode("previewBrand").color = accent()
    m.top.findNode("previewPill").uri = themed("pill")
    m.top.findNode("previewPillText").color = onAccent()
    m.top.findNode("previewBar").color = accent()
    m.top.findNode("previewText").color = "0x8E8E9EFF"
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "up" and m.sel > 0 then
        m.sel = m.sel - 1
    else if key = "down" and m.sel < m.rows.Count() - 1 then
        m.sel = m.sel + 1
    else if key = "left" then
        change(-1, false)
    else if key = "right" then
        change(1, false)
    else if key = "OK" then
        change(1, true)
    else
        return false   ' back goes to MainScene, which pops this screen
    end if
    paint()
    return true
end function
