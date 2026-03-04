-- PLAN: CLIENT, add an oxygen/drowning meter to the EHUD right column.
-- Only visible when underwater — dynamically added/removed from the column.
-- Uses EHUD.RegisterRightColumn + base_element pattern like other HUD elements.
-- Shows a numeric % display that turns red when oxygen is low.
RunClientLua([==[
local A = HL2Hud.Anim
local C = HL2Hud.Colors

local state = {
    fgColor = A.make(C.FgColor),
    bgColor = A.make(Color(0,0,0,0)),
    blur    = A.make(0),
}

local oxygen    = 100
local lastOxy   = 100
local lastWater = false

hook.Add("HL2Hud_ColorsChanged", "OxygenHud_Colors", function()
    C = HL2Hud.Colors
    A.snap(state.fgColor, C.FgColor)
end)

local function onOxygenChange(oxy)
    local col = oxy < 25 and C.DamagedFg or C.FgColor
    A.set(state.fgColor, col,            "Linear",  0,   0.1)
    A.set(state.bgColor, C.BgColor,      "Linear",  0,   0.1)
    A.set(state.bgColor, Color(0,0,0,0), "Linear",  0.1, 2.0)
    A.set(state.blur,    1,              "Linear",  0,   0.1)
    A.set(state.blur,    0,              "Deaccel", 0.1, 0.5)
end

local elem = {}

function elem:GetSize()
    local s = ScrH() / 480
    return 136*s, 36*s
end

function elem:Draw(x, y)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    A.step(state.fgColor)
    A.step(state.bgColor)
    A.step(state.blur)

    -- Drain oxygen while submerged
    if ply:WaterLevel() >= 3 then
        oxygen = math.max(0, oxygen - FrameTime() * 8)
    else
        oxygen = math.min(100, oxygen + FrameTime() * 20)
    end

    local oxy = math.Round(oxygen)
    if oxy ~= lastOxy then
        lastOxy = oxy
        onOxygenChange(oxy)
    end

    return HL2Hud.DrawNumericDisplay(x, y, "OXYGEN", oxy, state, { label = "%" })
end

-- Register right column and attach element.
-- Element's Draw returning nil when not underwater would work too,
-- but GetSize returning 0 height hides it cleanly from the stack.
local visElem = {}
local visible = false

function visElem:GetSize()
    if not visible then return 136*(ScrH()/480), 0 end
    return elem:GetSize()
end

function visElem:Draw(x, y)
    if not visible then return end
    return elem:Draw(x, y)
end

hook.Add("Think", "OxygenHud_Visibility", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    visible = ply:WaterLevel() >= 3
end)

EHUD.RegisterRightColumn("oxygen", 136, nil, 5)
local col = EHUD.GetColumn("oxygen")
if col then col.base_element = visElem end
]==])
Player({{ID}}):ChatPrint("Oxygen HUD active — appears in the right column when underwater.")
