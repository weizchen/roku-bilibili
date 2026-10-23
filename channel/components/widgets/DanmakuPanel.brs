sub init()
    m.alphas = [0.2, 0.4, 0.6, 0.8, 1.0]
    m.rowsDef = [
        { name: "弹幕", labels: ["关", "开"] }
        { name: "不透明度", labels: ["20%", "40%", "60%", "80%", "100%"] }
    ]
    m.top.findNode("heading").font = cjkFont(44)
    m.countLabel = m.top.findNode("countLabel")
    m.countLabel.font = cjkFont(26)
    hint = m.top.findNode("hint")
    hint.font = cjkFont(24)
    hint.text = "左右键调整　返回键关闭"

    m.rows = []
    group = m.top.findNode("rows")
    for i = 0 to m.rowsDef.Count() - 1
        g = group.createChild("Group")
        g.translation = [0, i * 104]
        chip = g.createChild("Poster")
        chip.uri = themed("chip")
        chip.width = 480
        chip.height = 84
        name = g.createChild("Label")
        name.font = cjkFont(32)
        name.text = m.rowsDef[i].name
        name.translation = [30, 0]
        name.height = 84
        name.vertAlign = "center"
        value = g.createChild("Label")
        value.font = cjkFont(32)
        value.translation = [190, 0]
        value.width = 260
        value.height = 84
        value.horizAlign = "right"
        value.vertAlign = "center"
        m.rows.Push({ chip: chip, name: name, value: value })
    end for
    m.sel = 0
    m.top.observeField("visible", "paint")
    paint()
end sub

function valueIndex(row as Integer) as Integer
    if row = 0 then
        if m.top.enabled then return 1
        return 0
    end if
    best = 3
    for i = 0 to m.alphas.Count() - 1
        if Abs(m.alphas[i] - m.top.alpha) < 0.05 then best = i
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
        m.top.enabled = (i = 1)
    else
        m.top.alpha = m.alphas[i]
    end if
    paint()
end sub

sub paint()
    if m.rows = invalid then return
    if m.top.count > 0 then
        m.countLabel.text = "本集共 " + m.top.count.ToStr() + " 条弹幕"
    else
        m.countLabel.text = "本集暂无弹幕"
    end if
    for i = 0 to m.rows.Count() - 1
        r = m.rows[i]
        focused = (i = m.sel)
        r.chip.visible = focused
        r.value.text = "‹  " + m.rowsDef[i].labels[valueIndex(i)] + "  ›"
        dimmed = (i = 1 and not m.top.enabled)
        if focused then
            r.name.color = onAccent()
            r.value.color = onAccent()
        else if dimmed then
            r.name.color = "0x55555FFF"
            r.value.color = "0x55555FFF"
        else
            r.name.color = "0xD2D2DCFF"
            r.value.color = "0xD2D2DCFF"
        end if
    end for
end sub

' Swallow everything while open so the player underneath does not seek.
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return true
    if key = "up" then
        m.sel = 0
    else if key = "down" then
        m.sel = 1
    else if key = "left" then
        change(-1, false)
    else if key = "right" then
        change(1, false)
    else if key = "OK" then
        change(1, true)
    else if key = "back" or key = "options" then
        m.top.closed = true
    end if
    paint()
    return true
end function
