RunClientLua([[
hook.Add("HUDPaint", "RedScreenOverlay", function()
    surface.SetDrawColor(255, 0, 0, 100)
    surface.DrawRect(0, 0, ScrW(), ScrH())
end)

timer.Simple(10, function()
    hook.Remove("HUDPaint", "RedScreenOverlay")
end)
]])

Player({{ID}}):ChatPrint("Screen will be red for 10 seconds!")