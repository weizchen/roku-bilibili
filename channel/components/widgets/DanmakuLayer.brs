' Each scrolling comment moves by its own Animation, so the render thread does the
' motion; a 0.2s tick only releases what is due at the current video time and
' recycles finished items. Lanes keep comments from overlapping, and everything
' moves at one speed so a later comment can never catch up with an earlier one.

sub init()
    m.speed = 230.0      ' px per second of video time
    m.laneH = 56
    m.laneTop = 36
    m.scrollLanes = 9    ' set from `area` below
    m.fixedLanes = 4
    m.fixedSecs = 4.0
    m.font = cjkFont(42)
    m.items = []
    m.cursor = 0
    m.playing = false
    m.basePos = 0.0
    m.clock = CreateObject("roTimespan")
    m.tick = m.top.findNode("tick")
    m.tick.observeField("fire", "onTick")
    buildPool(64)
    onArea()
end sub

' Rows that fit in the chosen share of the screen. Below full screen, bottom
' comments move up into the top rows so the lower part stays clear.
sub onArea()
    usable = 1080 * m.top.area - m.laneTop - 8
    m.scrollLanes = Int(usable / m.laneH)
    if m.scrollLanes < 1 then m.scrollLanes = 1
    m.fixedLanes = 4
    if m.fixedLanes > m.scrollLanes then m.fixedLanes = m.scrollLanes
    m.bottomAllowed = m.top.area >= 0.99
    if m.pool <> invalid then clearAll()
end sub

sub buildPool(n as Integer)
    pool = m.top.findNode("pool")
    m.pool = []
    for i = 0 to n - 1
        g = pool.createChild("Group")
        g.id = "dm" + i.ToStr()
        g.visible = false
        sh = g.createChild("Label")
        sh.font = m.font
        sh.color = "0x000000B4"
        sh.translation = [2, 2]
        lb = g.createChild("Label")
        lb.font = m.font
        anim = pool.createChild("Animation")
        anim.repeat = false
        anim.easeFunction = "linear"
        interp = anim.createChild("Vector2DFieldInterpolator")
        interp.fieldToInterp = g.id + ".translation"
        interp.key = [0.0, 1.0]
        m.pool.Push({ g: g, sh: sh, lb: lb, anim: anim, interp: interp, busy: false, scroll: false, until: 0.0 })
    end for
end sub

sub resetLanes()
    m.scrollFree = []
    m.centerClear = []   ' when the last scroller in a row has passed the middle of the screen
    for i = 0 to m.scrollLanes - 1
        m.scrollFree.Push(-1.0)
        m.centerClear.Push(-1.0)
    end for
    m.topFree = []
    m.bottomFree = []
    for i = 0 to m.fixedLanes - 1
        m.topFree.Push(-1.0)
        m.bottomFree.Push(-1.0)
    end for
end sub

' ---------- clock: video position, extrapolated between notifications ----------

sub onVideo()
    v = m.top.video
    if v = invalid then return
    v.observeField("position", "onPosition")
    v.observeField("state", "onState")
end sub

function now() as Float
    if m.playing then return m.basePos + m.clock.TotalMilliseconds() / 1000.0
    return m.basePos
end function

sub onPosition()
    p = m.top.video.position
    if Abs(p - now()) > 1.5 then
        seekTo(p)   ' the viewer jumped
    else
        m.basePos = p
        m.clock.Mark()
    end if
end sub

sub onState()
    s = m.top.video.state
    if s = "playing" then
        if not m.playing then
            m.basePos = m.top.video.position
            m.clock.Mark()
            m.playing = true
            setAnimations("resume")
        end if
        if m.top.enabled then m.tick.control = "start"
    else
        if m.playing then
            m.basePos = now()
            m.playing = false
        end if
        setAnimations("pause")
        m.tick.control = "stop"
        if s = "stopped" or s = "finished" or s = "error" then clearAll()
    end if
end sub

sub seekTo(p as Float)
    clearAll()
    m.basePos = p
    m.clock.Mark()
    m.cursor = lowerBound(p)
end sub

function lowerBound(t as Float) as Integer
    lo = 0
    hi = m.items.Count()
    while lo < hi
        half = (lo + hi) \ 2
        if m.items[half][0] < t then
            lo = half + 1
        else
            hi = half
        end if
    end while
    return lo
end function

' ---------- data ----------

sub onCid()
    clearAll()
    m.items = []
    m.cursor = 0
    m.top.count = 0
    if m.top.cid = "" then return
    m.task = api("danmaku", { cid: m.top.cid }, "onLoaded")
end sub

sub onLoaded(event as Object)
    res = event.getData()
    if not res.ok then return
    if strOf(res.data.cid) <> m.top.cid then return
    m.items = res.data.items
    m.top.count = m.items.Count()
    m.cursor = lowerBound(now())
end sub

sub onEnabled()
    if m.top.enabled then
        m.top.visible = true
        m.cursor = lowerBound(now())
        if m.playing then m.tick.control = "start"
    else
        m.tick.control = "stop"
        clearAll()
        m.top.visible = false
    end if
end sub

' ---------- spawning ----------

sub onTick()
    t = now()
    for each it in m.pool
        if it.busy and it.until <= t then release(it)
    end for
    n = m.items.Count()
    spawned = 0
    while m.cursor < n
        d = m.items[m.cursor]
        if d[0] > t then exit while
        m.cursor = m.cursor + 1
        ' skip a backlog (after a stall) instead of dumping it all at once
        if d[0] >= t - 1.0 and spawned < 6 then
            if spawn(d, t) then spawned = spawned + 1
        end if
    end while
end sub

function freeLane(lanes as Object, t as Float) as Integer
    for i = 0 to lanes.Count() - 1
        if lanes[i] <= t then return i
    end for
    return -1
end function

' Top comments sit centred on a scrolling row, so they only take a row whose
' scrollers have already passed the middle third of the screen.
function freeTopLane(t as Float) as Integer
    for i = 0 to m.fixedLanes - 1
        if m.topFree[i] <= t and m.centerClear[i] <= t then return i
    end for
    return -1
end function

function idleItem() as Dynamic
    for each it in m.pool
        if not it.busy then return it
    end for
    return invalid
end function

' d = [time, mode (1 scroll / 4 bottom / 5 top), color, text]
function spawn(d as Object, t as Float) as Boolean
    mode = d[1]
    if mode = 4 and not m.bottomAllowed then mode = 5
    if mode = 5 then
        lane = freeTopLane(t)
    else if mode = 4 then
        lane = freeLane(m.bottomFree, t)
    else
        lane = freeLane(m.scrollFree, t)
    end if
    if lane < 0 then return false
    it = idleItem()
    if it = invalid then return false

    it.lb.text = d[3]
    it.sh.text = d[3]
    it.lb.color = d[2]
    w = it.lb.boundingRect().width
    if mode = 4 or mode = 5 then
        if mode = 5 then
            y = m.laneTop + lane * m.laneH
            m.topFree[lane] = t + m.fixedSecs
            ' top comments share rows with scrolling ones; keep new scrollers out meanwhile
            if m.scrollFree[lane] < t + m.fixedSecs then m.scrollFree[lane] = t + m.fixedSecs
        else
            y = 1080 - 190 - lane * m.laneH
            m.bottomFree[lane] = t + m.fixedSecs
        end if
        it.anim.control = "stop"
        it.g.translation = [(1920 - w) / 2, y]
        it.scroll = false
        it.until = t + m.fixedSecs
    else
        y = m.laneTop + lane * m.laneH
        dur = (1920 + w) / m.speed
        ' the lane opens again once this comment's tail is on screen, plus a gap
        m.scrollFree[lane] = t + (w + 48) / m.speed
        m.centerClear[lane] = t + (1440 + w) / m.speed
        it.anim.control = "stop"
        it.anim.duration = dur
        it.interp.keyValue = [[1920, y], [-w - 4, y]]
        it.g.translation = [1920, y]
        it.anim.control = "start"
        if not m.playing then it.anim.control = "pause"
        it.scroll = true
        it.until = t + dur
    end if
    it.busy = true
    it.g.visible = true
    return true
end function

sub release(it as Object)
    it.anim.control = "stop"
    it.g.visible = false
    it.busy = false
end sub

sub clearAll()
    for each it in m.pool
        if it.busy then release(it)
    end for
    resetLanes()
end sub

sub setAnimations(cmd as String)
    for each it in m.pool
        if it.busy and it.scroll then it.anim.control = cmd
    end for
end sub
