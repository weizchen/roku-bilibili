' Entry point. Deep links (ECP launch/input with contentId=BV...) open a video directly:
'   curl -d '' "http://<tv>:8060/launch/dev?contentId=BV1xx411c7mD&mediaType=movie"
sub Main(args as Dynamic)
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    input = CreateObject("roInput")
    input.SetMessagePort(port)

    m.global = screen.GetGlobalNode()
    ' wbiKey/wbiAt: cached signing key; mpd*: manifest the loopback server hands the player
    ' theme and font are filled in by MainScene (it owns the theme table) before any screen exists
    m.global.AddFields({ loggedIn: hasSession(), wbiKey: "", wbiAt: 0, mpd: "", mpdId: "", mpdPort: 0, theme: {}, font: {}, uname: "" })

    scene = screen.CreateScene("MainScene")
    screen.Show()
    deeplink(scene, args)

    while true
        msg = wait(0, port)
        t = type(msg)
        if t = "roSGScreenEvent" then
            if msg.IsScreenClosed() then return
        else if t = "roInputEvent" then
            deeplink(scene, msg.GetInfo())
        end if
    end while
end sub

function hasSession() as Boolean
    sec = CreateObject("roRegistrySection", "bili")
    if not sec.Exists("cookies") then return false
    c = ParseJson(sec.Read("cookies"))
    if type(c) <> "roAssociativeArray" then return false
    t = type(c.sessdata)
    return t = "String" or t = "roString"
end function

sub deeplink(scene as Object, args as Dynamic)
    if args = invalid then return
    id = args.contentId
    if id = invalid then return
    if Len(id) < 3 then return
    scene.deeplink = { bvid: id, mediaType: args.mediaType }
end sub
