-- PLAN: CLIENT, freeze-frame kill cam on death.
-- On LocalPlayer death: snapshot the camera position/angle, freeze rendering there
-- via CalcView hook, slowly zoom toward the attacker, hold, then fade to black.
-- Uses RenderView override to freeze the world frame + DrawColorModify for effects.
RunClientLua([==[
local state = "idle"  -- idle | freeze | hold | fadeout
local camPos, camAng, camFov
local targetPos  -- zoom toward attacker's last known position
local stateStart = 0
local alpha      = 0  -- black overlay alpha 0..255

local FREEZE_ZOOM_TIME = 1.5  -- seconds to zoom in
local HOLD_TIME        = 2.0  -- seconds to hold frozen
local FADE_TIME        = 0.8  -- seconds to fade to black

hook.Add("LocalPlayerDied", "KillCam_Death", function(ply, inflictor, attacker)
    if state ~= "idle" then return end

    -- Snapshot current view
    camPos = EyePos()
    camAng = EyeAngles()
    camFov = LocalPlayer():GetFOV()
    if camFov == 0 then camFov = 90 end

    -- Zoom toward attacker if valid, else look at death position
    if IsValid(attacker) and attacker ~= ply then
        targetPos = attacker:GetPos() + Vector(0, 0, 64)
    else
        targetPos = ply:GetPos() + Vector(0, 0, 64)
    end

    state      = "freeze"
    stateStart = CurTime()
    alpha      = 0
end)

hook.Add("CalcView", "KillCam_CalcView", function(ply, origin, angles, fov)
    if state == "idle" then return end

    local now = CurTime()
    local t   = now - stateStart

    if state == "freeze" then
        -- Zoom FOV down and drift toward target
        local pct  = math.Clamp(t / FREEZE_ZOOM_TIME, 0, 1)
        local ease = 1 - (1 - pct)^2  -- ease out
        local zoomedFov = Lerp(ease, camFov, camFov * 0.55)

        -- Slowly rotate camera to look at target
        local dir      = (targetPos - camPos):GetNormalized()
        local wantAng  = dir:Angle()
        local lerpAng  = LerpAngle(ease * 0.4, camAng, wantAng)

        if t >= FREEZE_ZOOM_TIME then
            state = "hold"; stateStart = now
        end

        local view = {}
        view.origin = camPos
        view.angles = lerpAng
        view.fov    = zoomedFov
        return view

    elseif state == "hold" then
        local dir     = (targetPos - camPos):GetNormalized()
        local view    = {}
        view.origin   = camPos
        view.angles   = dir:Angle()
        view.fov      = camFov * 0.55
        if t >= HOLD_TIME then state = "fadeout"; stateStart = now end
        return view

    elseif state == "fadeout" then
        local pct  = math.Clamp(t / FADE_TIME, 0, 1)
        alpha      = math.Round(pct * 255)
        local dir  = (targetPos - camPos):GetNormalized()
        local view = {}
        view.origin = camPos
        view.angles = dir:Angle()
        view.fov    = camFov * 0.55
        if t >= FADE_TIME then
            state = "idle"
            alpha = 0
        end
        return view
    end
end)

hook.Add("HUDPaint", "KillCam_Overlay", function()
    if state == "idle" then return end

    -- Color grading: slight desaturate + contrast during freeze
    DrawColorModify({
        ["$pp_colour_addr"] = 0,
        ["$pp_colour_addg"] = 0,
        ["$pp_colour_addb"] = 0,
        ["$pp_colour_brightness"] = 0,
        ["$pp_colour_contrast"] = 1.1,
        ["$pp_colour_colour"] = 0.75,
        ["$pp_colour_mulr"] = 0,
        ["$pp_colour_mulg"] = 0,
        ["$pp_colour_mulb"] = 0,
    })

    -- "KILLED" text flash
    if state == "freeze" or state == "hold" then
        local t    = CurTime() - stateStart
        local a    = state == "hold" and 200 or math.Round(math.min(t / 0.3, 1) * 200)
        local s    = ScrH() / 480
        draw.SimpleText("YOU DIED", "HL2Hud_Numbers",
            ScrW() / 2, ScrH() / 2 - 40*s,
            Color(255, 40, 40, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Fade to black overlay
    if alpha > 0 then
        surface.SetDrawColor(0, 0, 0, alpha)
        surface.DrawRect(0, 0, ScrW(), ScrH())
    end
end)

Player({{ID}}):ChatPrint("Kill cam active — freeze frame zooms on death.")
]==])
