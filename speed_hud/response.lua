-- PLAN: CLIENT, add a speedometer to the EHUD left column.
-- Shows player velocity (XY plane) as a numeric display, HL2-styled.
-- Uses EHUD.RegisterLeftColumn + EHUD.AddToColumn pattern (NOT base_element).
-- Pulses bright on speed change using HL2Hud.Anim.
if SERVER then return end

RunClientLua([==[
local A = HL2Hud.Anim

local state = {
    fgColor  = A.make(HL2Hud.Colors.FgColor),
    fgGlow   = A.make(Color(0,0,0,0)),
    lastSpeed = -1,
}

local function onSpeedChange()
    local C = HL2Hud.Colors
    A.set(state.fgColor, C.BrightFg,  "Linear",  0,    0.1)
    A.set(state.fgColor, C.FgColor,   "Deaccel", 0.1,  0.5)
    A.set(state.fgGlow,  C.BrightFg,  "Linear",  0,    0.1)
    A.set(state.fgGlow,  Color(0,0,0,0), "Deaccel", 0.1, 0.5)
end

hook.Add("HL2Hud_ColorsChanged", "SpeedHud_Colors", function()
    A.snap(state.fgColor, HL2Hud.Colors.FgColor)
    A.snap(state.fgGlow,  Color(0,0,0,0))
end)

local elem = {}
function elem:GetSize()
    local s = ScrH() / 480
    return 102*s, 36*s
end

function elem:Draw(x, y)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    A.step(state.fgColor)
    A.step(state.fgGlow)

    local vel   = ply:GetVelocity()
    local speed = math.Round(Vector(vel.x, vel.y, 0):Length())

    if speed ~= state.lastSpeed then
        onSpeedChange()
        state.lastSpeed = speed
    end

    HL2Hud.DrawNumericDisplay(x, y, "SPEED", speed, state, {
        label = "UPS",
    })
end

-- Register as a new left column element, priority 25 (below health=100, suit=90)
EHUD.RegisterLeftColumn("speed", 102, nil, 25)
EHUD.AddToColumn("speed", "speed_display", elem, 1)
]==])

Player({{ID}}):ChatPrint("Speed HUD active — shows velocity in the left column.")
