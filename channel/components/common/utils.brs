' Helpers shared by every component (included with a <script> tag).

' Roku's system font has no CJK glyphs, so every label uses one of these bundled
' subsets (built by scripts/make-font.py; the first is the default).
function fonts() as Object
    return [
        { key: "kai", name: "楷体", uri: "pkg:/fonts/kai.ttf" }
        { key: "hei", name: "黑体", uri: "pkg:/fonts/hei.ttf" }
        { key: "song", name: "宋体", uri: "pkg:/fonts/song.otf" }
    ]
end function

function fontByKey(key as String) as Object
    for each f in fonts()
        if f.key = key then return f
    end for
    return fonts()[0]
end function

function cjkFont(size as Integer) as Object
    f = CreateObject("roSGNode", "Font")
    f.uri = currentFont().uri
    f.size = size
    return f
end function

' ---------- theme ----------
' Accent colours (keep in step with THEMES in scripts/make-art.py, which draws the
' matching focus_/pill_/chip_/spinner_ images). onAccent is the text colour on an
' accent background: dark on the light accents, white on the deep ones.

function themes() as Object
    return [
        { key: "yellow", name: "黄色", accent: "0xFFC93CFF", onAccent: "0x1B1B20FF" }
        { key: "pink", name: "粉色", accent: "0xFB7299FF", onAccent: "0xFFFFFFFF" }
        { key: "blue", name: "蓝色", accent: "0x3D8BFDFF", onAccent: "0xFFFFFFFF" }
        { key: "green", name: "绿色", accent: "0x34D399FF", onAccent: "0x10261CFF" }
        { key: "purple", name: "紫色", accent: "0x9B7BFFFF", onAccent: "0xFFFFFFFF" }
    ]
end function

function themeByKey(key as String) as Object
    for each t in themes()
        if t.key = key then return t
    end for
    return themes()[0]
end function

' The global theme/font are set by MainScene; fall back to the defaults when they
' are not there (a component built while the channel is being torn down).
function currentTheme() as Object
    t = invalid
    if m.global <> invalid then t = m.global.theme
    if type(t) = "roAssociativeArray" then
        if not isNil(t.key) then return t
    end if
    return themes()[0]
end function

function currentFont() as Object
    f = invalid
    if m.global <> invalid then f = m.global.font
    if type(f) = "roAssociativeArray" then
        if not isNil(f.uri) then return f
    end if
    return fonts()[0]
end function

function accent() as String
    return currentTheme().accent
end function

function onAccent() as String
    return currentTheme().onAccent
end function

' "pill" -> pkg:/images/pill_yellow.9.png; spinner art is not a 9-patch
function themed(name as String) as String
    if name = "spinner" then return "pkg:/images/spinner_" + currentTheme().key + ".png"
    return "pkg:/images/" + name + "_" + currentTheme().key + ".9.png"
end function

function isNil(v as Dynamic) as Boolean
    t = type(v)
    return t = "Invalid" or t = "roInvalid" or t = "<uninitialized>"
end function

function strOf(v as Dynamic) as String
    if isNil(v) then return ""
    t = type(v)
    if t = "String" or t = "roString" then return v
    return v.ToStr()
end function

function intOf(v as Dynamic) as Integer
    if isNil(v) then return 0
    t = type(v)
    if t = "String" or t = "roString" then return v.ToInt()
    if t = "Float" or t = "roFloat" or t = "Double" or t = "roDouble" then return Int(v)
    if t = "Boolean" or t = "roBoolean" then return 0
    return v
end function

function boolOf(v as Dynamic) as Boolean
    t = type(v)
    if t = "Boolean" or t = "roBoolean" then return v
    return false
end function

function fmtTime(sec as Integer) as String
    if sec < 0 then sec = 0
    h = sec \ 3600
    mn = (sec mod 3600) \ 60
    s = sec mod 60
    ss = s.ToStr()
    if s < 10 then ss = "0" + ss
    if h > 0 then
        mm = mn.ToStr()
        if mn < 10 then mm = "0" + mm
        return h.ToStr() + ":" + mm + ":" + ss
    end if
    return mn.ToStr() + ":" + ss
end function

' Run a bilibili operation on a BiliTask; `callback` gets the task's response field change.
function api(op as String, params as Dynamic, callback as String, tag = "" as String) as Object
    task = CreateObject("roSGNode", "BiliTask")
    task.op = op
    if params <> invalid then task.params = params
    task.tag = tag
    task.observeField("response", callback)
    task.control = "RUN"
    return task
end function

sub navigate(action as Object)
    m.top.getScene().nav = action
end sub

sub toast(text as String)
    navigate({ action: "toast", text: text })
end sub

' Video cards from the proxy -> ContentNode children (for grids and rows).
function cardsToContent(items as Dynamic, parent as Object) as Object
    if items = invalid then return parent
    for each it in items
        node = parent.createChild("ContentNode")
        node.addFields({
            bvid: strOf(it.bvid)
            aid: strOf(it.aid)
            cid: strOf(it.cid)
            up: strOf(it.up)
            viewText: strOf(it.view_text)
            dateText: strOf(it.date_text)
            durationText: strOf(it.duration_text)
            seconds: intOf(it.duration)
            progress: intOf(it.progress)
            history: boolOf(it.history)
            roomid: strOf(it.roomid)
            statsText: strOf(it.stats_text)
            live: boolOf(it.live)
        })
        node.title = strOf(it.title)
        node.HDPosterUrl = strOf(it.poster)
    end for
    return parent
end function

' ---------- small persistent settings ----------

' What the player does when a video ends (setting "play_mode").
function playModes() as Object
    return [
        { key: "stop", name: "播完停止" }
        { key: "next", name: "自动连播" }
        { key: "loop", name: "单集循环" }
    ]
end function

function playMode() as String
    return loadSetting("play_mode", "next")
end function

' How much of the screen, from the top, danmaku may cover (setting "dm_area").
function danmakuAreas() as Object
    return [0.25, 0.5, 0.75, 1.0]
end function

function danmakuAreaNames() as Object
    return ["25%", "50%", "75%", "100%"]
end function

' Index of the list value nearest x (settings are stored as text).
function nearestIndex(list as Object, x as Float) as Integer
    best = 0
    for i = 1 to list.Count() - 1
        if Abs(list[i] - x) < Abs(list[best] - x) then best = i
    end for
    return best
end function

function loadSetting(key as String, fallback as String) as String
    sec = CreateObject("roRegistrySection", "bili")
    if sec.Exists(key) then return sec.Read(key)
    return fallback
end function

sub saveSetting(key as String, value as String)
    sec = CreateObject("roRegistrySection", "bili")
    sec.Write(key, value)
    sec.Flush()
end sub

' ---------- local watch progress (registry is capped at 16KB, so keep a short MRU list) ----------

function progressList() as Object
    sec = CreateObject("roRegistrySection", "bili")
    if not sec.Exists("progress") then return []
    list = ParseJson(sec.Read("progress"))
    if type(list) <> "roArray" then return []
    return list
end function

function loadProgress(bvid as String) as Dynamic
    for each e in progressList()
        if e.b = bvid then return e
    end for
    return invalid
end function

sub forgetProgress(bvid as String)
    saveProgress(bvid, 0, 0, 0)   ' a zero bookmark is dropped rather than stored
end sub

sub forgetAllProgress()
    sec = CreateObject("roRegistrySection", "bili")
    sec.Delete("progress")
    sec.Flush()
end sub

sub saveProgress(bvid as String, index as Integer, secs as Integer, dur as Integer)
    list = progressList()
    kept = []
    for each e in list
        if e.b <> bvid then kept.Push(e)
    end for
    finished = dur > 0 and secs > dur - 20
    if not finished and (secs >= 10 or index > 0) then kept.Unshift({ b: bvid, i: index, p: secs, d: dur })
    while kept.Count() > 80
        kept.Pop()
    end while
    sec = CreateObject("roRegistrySection", "bili")
    sec.Write("progress", FormatJson(kept))
    sec.Flush()
end sub
