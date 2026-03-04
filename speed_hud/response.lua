-- PLAN: CLIENT, add a speedometer to the EHUD left column.
-- Registers a new left column "speed" and sets base_element to a numeric display.
-- Shows XY velocity in units/sec. Pulses on speed change. Uses HL2Hud.Colors.
RunClientLua([==[
local A = HL2Hud.Anim
local C = HL2Hud.Colors

local state = {
    fgColor = A.make(C.FgColor),
    bgColor = A.make(Color(0,0,0,0)),
    blur    = A.make(0),
}

local lastSpeed = -1

local function onSpeedChange()
    A.set(state.fgColor, C.BrightFg,       "Linear",  0,   0.1)
    A.set(state.fgColor, C.FgColor,         "Deaccel", 0.1, 0.5)
    A.set(state.bgColor, C.BgColor,         "Linear",  0,   0.1)
    A.set(state.bgColor, Color(0,0,0,0),    "Linear",  0.1, 2.0)
    A.set(state.blur,    1,                 "Linear",  0,   0.1)
    A.set(state.blur,    0,                 "Deaccel", 0.1, 0.5)
end

hook.Add("HL2Hud_ColorsChanged", "SpeedHud_Colors", function()
    C = HL2Hud.Colors
    A.snap(state.fgColor, C.FgColor)
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
    A.step(state.bgColor)
    A.step(state.blur)

    local vel   = ply:GetVelocity()
    local speed = math.Round(Vector(vel.x, vel.y, 0):Length())

    if speed ~= lastSpeed then
        lastSpeed = speed
        onSpeedChange()
    end

    return HL2Hud.DrawNumericDisplay(x, y, "SPEED", speed, state)
end

EHUD.RegisterLeftColumn("speed", 102, nil, 25)
local col = EHUD.GetColumn("speed")
if col then col.base_element = elem end
]==])
Player({{ID}}):ChatPrint("Speed HUD active.")
