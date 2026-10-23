' Helpers shared by every component (included with a <script> tag).

function cjkFont(size as Integer) as Object
    ' Roku's system font has no CJK glyphs, so every label uses the bundled subset.
    f = CreateObject("roSGNode", "Font")
    f.uri = "pkg:/fonts/cjk.otf"
    f.size = size
    return f
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
        })
        node.title = strOf(it.title)
        node.HDPosterUrl = strOf(it.poster)
    end for
    return parent
end function

' ---------- small persistent settings ----------

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
