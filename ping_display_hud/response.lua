-- PLAN: CLIENT, HL2-style ping display using EHUD + shared GilbUtils infrastructure.
-- Registers as a new left column (priority 30, after health=10 and suit=20).
-- Green < 100ms, yellow 100–149ms, red >= 150ms with pulse + glow.
-- Uses HL2Hud.MakeLayout("health") for full theme awareness (fonts, panel style, icons).
RunClientLua([==[
if not EHUD then include("autorun/client/cl_extensible_hud.lua") end

local A    = HL2Hud.Anim
local make = A.make
local set  = A.set
local step = A.step
local snap = A.snap

local C = HL2Hud.Colors

-- HL2 HUD event-driven animation state (mirrors CHudNumericDisplay)
local state = {
    fgColor = make(C.FgColor),
    bgColor = make(C.BgColor),
    blur    = make(0),
}

local lastPing   = 0
local lastSample = 0

local function targetColor(ping)
    if ping >= 150 then return Color(255, 0, 0, 255)
    elseif ping >= 100 then return C.FgColor
    else return Color(100, 220, 60, 255)
    end
end

local function onPingChange(ping)
    local col = targetColor(ping)
    set(state.fgColor, col,   "Linear",  0,   0.4)
    set(state.blur,    1,     "Linear",  0,   0.1)
    set(state.blur,    0,     "Deaccel", 0.1, 2.0)
    if ping >= 150 then
        snap(state.bgColor, C.DamagedBg)
    else
        set(state.bgColor, C.BgColor, "Deaccel", 0, 0.5)
    end
end

local elem = {}

function elem:GetSize()
    local layout = HL2Hud.GetLayout("health")
    local s = ScrH() / 480
    return (layout and layout.wide or 102) * s, (layout and layout.tall or 36) * s
end

function elem:Draw(x, y, clip_h)
    local now = CurTime()

    -- Sample ping every 0.5s
    if now - lastSample > 0.5 then
        lastSample = now
        local ply  = LocalPlayer()
        local ping = IsValid(ply) and ply:Ping() or 0
        if ping ~= lastPing then
            lastPing = ping
            onPingChange(ping)
        end
    end

    step(state.fgColor)
    step(state.bgColor)
    step(state.blur)

    local base = HL2Hud.GetLayout("health")
    local layout = HL2Hud.MakeLayout("health", {
        label     = "PING",
        icon_char = nil,
        -- CSS has no text_xpos; inject label at icon position as text fallback
        text_xpos = base.text_xpos == nil and (base.icon_xpos or 8) or nil,
        text_ypos = base.text_xpos == nil and math.max(0, (base.icon_ypos or 0)) or nil,
    })
    return HL2Hud.DrawElement(x, y, lastPing, state, layout)
end

-- Hook into ColorsChanged so recoloring updates ping too
hook.Add("HL2Hud_ColorsChanged", "PingHud_ColorsChanged", function()
    C = HL2Hud.Colors
    snap(state.fgColor, targetColor(lastPing))
    snap(state.bgColor, C.BgColor)
end)

EHUD.RegisterLeftColumn("ping", 102, nil, 30)
local col = EHUD.GetColumn("ping")
if col then col.base_element = elem end
]==])
Player({{ID}}):ChatPrint("Ping HUD loaded.")
