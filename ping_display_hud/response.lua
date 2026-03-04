-- PLAN: CLIENT, HL2-style ping display using EHUD + shared GilbUtils infrastructure.
-- Registers as a new left column (priority 30, after health=10 and suit=20).
-- Green < 100ms, yellow 100–149ms, red >= 150ms with pulse + glow.
-- Uses HL2Hud.DrawNumericDisplay and HL2Hud.Colors for consistent theming.
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
    bgColor = make(Color(0, 0, 0, 0)),
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
    set(state.fgColor, col,              "Linear", 0, 0.4)
    set(state.bgColor, C.BgColor,        "Linear", 0, 0.1)
    set(state.bgColor, Color(0,0,0,0),   "Linear", 0.1, 2.0)
    set(state.blur,    1,                "Linear", 0, 0.1)
    set(state.blur,    0,                "Deaccel", 0.1, 2.0)
    if ping >= 150 then
        -- Keep fgColor red + pulse bg while bad (re-fire every sample)
        snap(state.bgColor, C.DamagedBg)
    end
end

local elem = {}

function elem:GetSize()
    local s = ScrH() / 480
    return 102*s, 36*s
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

    return HL2Hud.DrawNumericDisplay(x, y, "PING", lastPing, state)
end

-- Hook into ColorsChanged so recoloring updates ping too
hook.Add("HL2Hud_ColorsChanged", "PingHud_ColorsChanged", function()
    C = HL2Hud.Colors
    snap(state.fgColor, targetColor(lastPing))
end)

EHUD.RegisterLeftColumn("ping", 102, nil, 30)
local col = EHUD.GetColumn("ping")
if col then col.base_element = elem end
]==])
Player({{ID}}):ChatPrint("Ping HUD loaded.")
