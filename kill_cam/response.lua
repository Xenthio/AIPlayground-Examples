-- PLAN: CLIENT, freeze-frame kill cam on death.
-- Hooks PlayerDeath (clientside) to detect local player death.
-- CalcView freezes the camera, zooms toward the killer, holds, then fades to black.
RunClientLua([==[
local state      = "idle"
local camPos, camAng, camFov, targetPos
local stateStart = 0
local alpha      = 0

local ZOOM_TIME  = 1.5
local HOLD_TIME  = 2.0
local FADE_TIME  = 0.8

-- GMod clientside death hook: PlayerDeath fires on all clients
hook.Add("PlayerDeath", "KillCam_Death", function(victim, inflictor, attacker)
    if victim ~= LocalPlayer() then return end
    if state ~= "idle" then return end

    camPos = EyePos()
    camAng = EyeAngles()
    camFov = LocalPlayer():GetFOV()
    if camFov == 0 then camFov = 90 end

    targetPos = IsValid(attacker) and attacker ~= victim
        and (attacker:GetPos() + Vector(0, 0, 64))
        or  (victim:GetPos()   + Vector(0, 0, 64))

    state      = "freeze"
    stateStart = CurTime()
    alpha      = 0
end)

hook.Add("CalcView", "KillCam_CalcView", function(ply, origin, angles, fov)
    if state == "idle" then return end

    local t   = CurTime() - stateStart
    local view = {}
    view.origin = camPos

    if state == "freeze" then
        local ease     = 1 - (1 - math.Clamp(t / ZOOM_TIME, 0, 1)) ^ 2
        view.angles    = LerpAngle(ease * 0.4, camAng, (targetPos - camPos):Angle())
        view.fov       = Lerp(ease, camFov, camFov * 0.55)
        if t >= ZOOM_TIME then state = "hold"; stateStart = CurTime() end

    elseif state == "hold" then
        view.angles = (targetPos - camPos):Angle()
        view.fov    = camFov * 0.55
        if t >= HOLD_TIME then state = "fadeout"; stateStart = CurTime() end

    elseif state == "fadeout" then
        view.angles = (targetPos - camPos):Angle()
        view.fov    = camFov * 0.55
        alpha = math.Round(math.Clamp(t / FADE_TIME, 0, 1) * 255)
        if t >= FADE_TIME then state = "idle"; alpha = 0 end
    end

    return view
end)

hook.Add("HUDPaint", "KillCam_Overlay", function()
    if state == "idle" then return end

    DrawColorModify({
        ["$pp_colour_addr"]       = 0,
        ["$pp_colour_addg"]       = 0,
        ["$pp_colour_addb"]       = 0,
        ["$pp_colour_brightness"] = 0,
        ["$pp_colour_contrast"]   = 1.1,
        ["$pp_colour_colour"]     = 0.75,
        ["$pp_colour_mulr"]       = 0,
        ["$pp_colour_mulg"]       = 0,
        ["$pp_colour_mulb"]       = 0,
    })

    if state == "freeze" or state == "hold" then
        local t = CurTime() - stateStart
        local a = state == "hold" and 200 or math.Round(math.min(t / 0.3, 1) * 200)
        local s = ScrH() / 480
        draw.SimpleText("YOU DIED", "HL2Hud_Numbers",
            ScrW() / 2, ScrH() / 2 - 40 * s,
            Color(255, 40, 40, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    if alpha > 0 then
        surface.SetDrawColor(0, 0, 0, alpha)
        surface.DrawRect(0, 0, ScrW(), ScrH())
    end
end)

Player({{ID}}):ChatPrint("Kill cam active.")
]==])
