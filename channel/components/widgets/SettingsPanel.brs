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
    m.modes = playModes()
    modeNames = []
    for each md in m.modes
        modeNames.Push(md.name)
    end for
    m.areas = danmakuAreas()
    ' key: what valueIndex() and change() switch on
    m.rowsDef = [
        { key: "theme", name: "主题色", labels: names }
        { key: "font", name: "字体", labels: fontNames }
        { key: "mode", name: "播放模式", labels: modeNames }
        { key: "dm_on", name: "弹幕默认", labels: ["关", "开"] }
        { key: "dm_alpha", name: "弹幕不透明度", labels: ["20%", "40%", "60%", "80%", "100%"] }
        { key: "dm_area", name: "弹幕显示区域", labels: danmakuAreaNames() }
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
    key = m.rowsDef[row].key
    if key = "theme" then
        for i = 0 to m.themeList.Count() - 1
            if m.themeList[i].key = currentTheme().key then return i
        end for
        return 0
    else if key = "font" then
        for i = 0 to m.fontList.Count() - 1
            if m.fontList[i].key = currentFont().key then return i
        end for
        return 0
    else if key = "mode" then
        for i = 0 to m.modes.Count() - 1
            if m.modes[i].key = playMode() then return i
        end for
        return 0
    else if key = "dm_on" then
        if loadSetting("dm_on", "1") = "1" then return 1
        return 0
    else if key = "dm_alpha" then
        return nearestIndex(m.alphas, Val(loadSetting("dm_alpha", "0.8")))
    end if
    return nearestIndex(m.areas, Val(loadSetting("dm_area", "0.5")))
end function

sub change(delta as Integer, wrap as Boolean)
    count = m.rowsDef[m.sel].labels.Count()
    i = valueIndex(m.sel) + delta
    if wrap then
        i = (i + count) mod count
    else if i < 0 or i >= count then
        return
    end if
    key = m.rowsDef[m.sel].key
    if key = "theme" then
        ' the home screen and its cards repaint themselves off this global
        m.global.theme = m.themeList[i]
        saveSetting("theme", m.themeList[i].key)
    else if key = "font" then
        ' the rest of the app picks the new font up as screens are rebuilt
        m.global.font = m.fontList[i]
        saveSetting("font", m.fontList[i].key)
        applyFonts()
    else if key = "mode" then
        saveSetting("play_mode", m.modes[i].key)
    else if key = "dm_on" then
        if i = 1 then
            saveSetting("dm_on", "1")
        else
            saveSetting("dm_on", "0")
        end if
    else if key = "dm_alpha" then
        saveSetting("dm_alpha", Str(m.alphas[i]).Trim())
    else
        saveSetting("dm_area", Str(m.areas[i]).Trim())
    end if
    paint()
end sub

sub onRow()
    m.sel = m.top.row
    paint()
end sub

sub paint()
    if m.rows = invalid then return
    for i = 0 to m.rows.Count() - 1
        r = m.rows[i]
        focused = (i = m.sel) and m.top.active
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

' up on the first row, back, etc. fall through to the home screen
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
        return false
    end if
    paint()
    return true
end function
