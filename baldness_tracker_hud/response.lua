-- PLAN: CLIENT, add a "Baldness Tracker" HUD column using EHUD + HL2Hud shared infrastructure.
-- Registers a new left column (priority 35, after health/suit/ping).
-- Base element: HL2-style numeric display showing baldness level (0-100).
-- Vstack above: chunked aux-style bar with funny hair loss status labels.
-- Vstack above that: hair strand follicle visualizer element.
RunClientLua([==[
if not EHUD then include("autorun/client/cl_extensible_hud.lua") end

-- Baldness state — persists across reloads
AIChaos_BaldnessState = AIChaos_BaldnessState or {
    level    = 0,
    rate     = 0.5,  -- units per second
    lastTime = CurTime(),
}

local function getBaldness()
    local now = CurTime()
    local dt  = now - AIChaos_BaldnessState.lastTime
    AIChaos_BaldnessState.lastTime = now
    AIChaos_BaldnessState.level = math.min(100,
        AIChaos_BaldnessState.level + AIChaos_BaldnessState.rate * dt)
    return math.Round(AIChaos_BaldnessState.level)
end

local function getHairLabels(lvl)
    local labels = {}
    if lvl >= 100 then
        table.insert(labels, "CHROME DOME")
    elseif lvl >= 80 then
        table.insert(labels, "CHROME DOME")
        table.insert(labels, "BUFFING SCALP")
    elseif lvl >= 60 then
        table.insert(labels, "COMB OVER")
        table.insert(labels, "NOT WORKING")
    elseif lvl >= 40 then
        table.insert(labels, "RECEDING")
    elseif lvl >= 20 then
        table.insert(labels, "THINNING")
    else
        table.insert(labels, "FULL HEAD")
    end
    return labels
end

-- ---- Base numeric element (baldness level) ---------------------------------
local A = HL2Hud.Anim
local state = {
    fgColor = A.make(HL2Hud.Colors.FgColor),
    bgColor = A.make(HL2Hud.Colors.BgColor),
    blur    = A.make(0),
}
local lastBald = 0

local function onBaldnessChange()
    local C = HL2Hud.Colors
    A.set(state.fgColor, C.BrightFg, "Linear", 0, 0.15)
    A.set(state.fgColor, C.FgColor,  "Deaccel", 0.15, 1.5)
    A.set(state.blur, 1, "Linear", 0, 0)
    A.set(state.blur, 0, "Deaccel", 0, 1.5)
end

local baseElem = {}
function baseElem:GetSize()
    local layout = HL2Hud.GetLayout("health")
    local s = ScrH()/480
    return (layout and layout.wide or 102)*s, (layout and layout.tall or 36)*s
end
function baseElem:Draw(x, y, clip_h)
    local bald = getBaldness()
    if bald ~= lastBald then onBaldnessChange() lastBald = bald end
    A.step(state.fgColor) A.step(state.bgColor) A.step(state.blur)
    local base = HL2Hud.GetLayout("health")
    local layout = HL2Hud.MakeLayout("health", {
        label     = "BALDNESS",
        icon_char = nil,
        text_xpos = base.text_xpos == nil and (base.icon_xpos or 8) or nil,
        text_ypos = base.text_xpos == nil and math.max(0, (base.icon_ypos or 0)) or nil,
    })
    return HL2Hud.DrawElement(x, y, bald, state, layout)
end

hook.Add("HL2Hud_ColorsChanged", "BaldHud_ColorsChanged", function()
    A.snap(state.fgColor, HL2Hud.Colors.FgColor)
    A.snap(state.bgColor, HL2Hud.Colors.BgColor)
end)

-- ---- Aux-style hair loss meter (chunked bar + funny labels) -----------------
local hairMeterElem = {}
function hairMeterElem:GetSize()
    local s    = ScrH() / 480
    local lvl  = AIChaos_BaldnessState.level
    local rows = #getHairLabels(math.Round(lvl))
    return 102*s, (26 + rows * 10) * s
end
function hairMeterElem:Draw(x, y, clip_h)
    local s    = ScrH() / 480
    local lvl  = AIChaos_BaldnessState.level
    local bald = math.Round(lvl)
    local labels = getHairLabels(bald)
    local h    = (26 + #labels * 10) * s
    local C    = HL2Hud.Colors
    local col  = C.FgColor

    draw.RoundedBox(6, x, y, 102*s, h, C.BgColor)

    surface.SetFont("HL2Hud_Text")
    surface.SetTextColor(col)
    surface.SetTextPos(x + 8*s, y + 4*s)
    surface.DrawText("HAIR LOSS")

    -- Chunked bar
    local bx, by = x + 8*s, y + 15*s
    local cw, cg = 6*s, 3*s
    local count  = math.floor(92*s / (cw + cg))
    local filled = math.floor(count * (lvl / 100) + 0.5)
    local cx = bx
    surface.SetDrawColor(col)
    for i = 1, filled       do surface.DrawRect(cx, by, cw, 4*s) cx = cx + cw + cg end
    surface.SetDrawColor(Color(col.r, col.g, col.b, HL2Hud.Colors.AuxDisabled or 50))
    for i = filled+1, count do surface.DrawRect(cx, by, cw, 4*s) cx = cx + cw + cg end

    -- Status labels
    local iy = y + 22*s
    surface.SetTextColor(col)
    for _, name in ipairs(labels) do
        surface.SetTextPos(x + 8*s, iy)
        surface.DrawText(name)
        iy = iy + 10*s
    end

    return 102*s, h
end

-- ---- Follicle visualizer (vstack above meter) --------------------------------
local follicleElem = {}
function follicleElem:GetSize() local s=ScrH()/480 return 102*s, 30*s end
function follicleElem:Draw(x, y, clip_h)
    local s   = ScrH() / 480
    local w   = 102*s
    local h   = 30*s
    local C   = HL2Hud.Colors
    local col = C.FgColor

    draw.RoundedBox(6, x, y, w, h, C.BgColor)

    surface.SetFont("HL2Hud_Text")
    surface.SetTextColor(col)
    surface.SetTextPos(x + 8*s, y + 4*s)
    surface.DrawText("FOLLICLES")

    local maxHairs   = 10
    local remaining  = math.Round(maxHairs * (1 - AIChaos_BaldnessState.level / 100))
    local hairStartX = x + 8*s
    local hairBaseY  = y + 26*s

    for i = 1, maxHairs do
        local hx    = hairStartX + (i - 1) * (8*s)
        local present = i <= remaining
        local sway  = present and (math.sin(CurTime() * 2 + i) * 2*s) or 0
        local c     = present and col or Color(col.r, col.g, col.b, 40)
        surface.SetDrawColor(c)
        surface.DrawLine(hx,         hairBaseY,
                         hx + sway,  hairBaseY - 12*s)
        surface.DrawLine(hx + 1,         hairBaseY,
                         hx + sway + 1,  hairBaseY - 12*s)
    end

    return w, h
end

-- ---- Register ---------------------------------------------------------------
EHUD.RegisterLeftColumn("baldness", 102, nil, 35)
local col = EHUD.GetColumn("baldness")
if col then
    col.base_element = baseElem
    EHUD.AddToColumn("baldness", "hair_meter",  hairMeterElem,  10)
    EHUD.AddToColumn("baldness", "follicles",   follicleElem,   20)
end
]==])
Player({{ID}}):ChatPrint("Baldness Tracker initialized. Current level: " .. math.Round(AIChaos_BaldnessState and AIChaos_BaldnessState.level or 0) .. "%")
