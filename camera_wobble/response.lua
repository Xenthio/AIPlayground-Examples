RunClientLua([[
hook.Add("CalcView", "CameraWobble", function(ply, pos, angles, fov)
    local view = {}
    view.origin = pos
    view.angles = angles + Angle(math.sin(CurTime() * 3) * 5, math.cos(CurTime() * 4) * 5, math.sin(CurTime() * 5) * 3)
    view.fov = fov
    return view
end)

timer.Simple(5, function()
    hook.Remove("CalcView", "CameraWobble")
end)
]])

Player({{ID}}):ChatPrint("Camera will wobble for 5 seconds!")