-- PLAN: CLIENT, add a speedometer to the EHUD left column.
-- Registers a new left column "speed" and sets base_element to a numeric display.
-- Shows XY velocity in units/sec. Pulses on speed change. Uses active theme layout via MakeLayout.
RunClientLua([==[
local A = HL2Hud.Anim
local C = HL2Hud.Colors

local state = {
    fgColor = A.make(C.FgColor),
    bgColor = A.make(C.BgColor),
    blur    = A.make(0),
}

local lastSpeed = -1

local function onSpeedChange()
    A.set(state.fgColor, C.BrightFg,  "Linear",  0,   0.1)
    A.set(state.fgColor, C.FgColor,   "Deaccel", 0.1, 0.5)
    A.set(state.bgColor, C.DamagedBg, "Linear",  0,   0)
    A.set(state.bgColor, C.BgColor,   "Deaccel", 0,   0.5)
    A.set(state.blur,    1,           "Linear",  0,   0.1)
    A.set(state.blur,    0,           "Deaccel", 0.1, 0.5)
end

hook.Add("HL2Hud_ColorsChanged", "SpeedHud_Colors", function()
    C = HL2Hud.Colors
    A.snap(state.fgColor, C.FgColor)
    A.snap(state.bgColor, C.BgColor)
end)

local elem = {}

function elem:GetSize()
    local layout = HL2Hud.GetLayout("health")
    local s = ScrH() / 480
    return 102 * s, (layout.tall or 36) * s
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

    local base = HL2Hud.GetLayout("health")
    local hasIcon = base.icon_char ~= nil
    local layout = HL2Hud.MakeLayout("health", {
        -- NOTE: `label` is the small descriptor text drawn via HL2Hud_Text font.
        -- The numeric value (speed) is always drawn separately using layout.font (CSS_Numbers / HL2Hud_Numbers).
        -- Do NOT put string text into the value passed to DrawElement — it only accepts numbers.
        label     = "SPEED",
        icon_char = hasIcon and "D" or nil,
        icon_font = hasIcon and "HL2Hud_WeaponIcons" or nil,
        icon_ypos = hasIcon and ((base.icon_ypos or 0) - 11) or nil,
        -- CSS has no text_xpos; when icon unavailable, inject label at icon position as text fallback
        text_xpos = (not hasIcon and base.text_xpos == nil) and (base.icon_xpos or 8) or nil,
        text_ypos = (not hasIcon and base.text_xpos == nil) and math.max(0, (base.icon_ypos or 0)) or nil,
    })
    return HL2Hud.DrawElement(x, y, speed, state, layout)
end

EHUD.RegisterLeftColumn("speed", 102, nil, 25)
local col = EHUD.GetColumn("speed")
if col then col.base_element = elem end
]==])
Player({{ID}}):ChatPrint("Speed HUD active.")
