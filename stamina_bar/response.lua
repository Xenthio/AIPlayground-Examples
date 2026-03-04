-- PLAN: CLIENT, replace the HL2 suit power bar with a custom stamina bar.
-- Replaces the suitpower column base_element via EHUD.GetColumn("suitpower").base_element.
-- Drains while sprinting, regens when stopped. Uses HL2Hud.Colors for theming.
-- NOTE: EHUD.GetColumn("suitpower") returns the aux/suit-power column;
--       setting .base_element replaces the chunked suit power bar drawn by hud_suit_power.lua.
if SERVER then return end

RunClientLua([==[
local stamina    = 100   -- 0..100
local MAX        = 100
local DRAIN_RATE = 20    -- per second while sprinting
local REGEN_RATE = 10    -- per second while not sprinting
local lastT      = CurTime()

local elem = {}

function elem:GetSize()
    local s = ScrH() / 480
    return 102*s, 26*s
end

function elem:Draw(x, y)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local now = CurTime()
    local dt  = now - lastT
    lastT     = now

    local sprinting = ply:IsSprinting()
    if sprinting then
        stamina = math.max(0, stamina - DRAIN_RATE * dt)
    else
        stamina = math.min(MAX, stamina + REGEN_RATE * dt)
    end

    local s    = ScrH() / 480
    local C    = HL2Hud.Colors
    local low  = stamina < 25
    local col  = low and C.DamagedFg or C.FgColor
    local w, h = 102*s, 26*s

    HL2Hud.DrawPanel(x, y, w, h)

    -- Label
    draw.SimpleText("STAMINA", "HL2Hud_Text", x + 4*s, y + 3*s, col)

    -- Chunked bar (matches hud_suit_power.lua style: 6px chunks, 3px gap)
    local chunkW = math.Round(6 * s)
    local chunkH = math.Round(8 * s)
    local gap    = math.Round(3 * s)
    local barY   = y + h - chunkH - 4*s
    local barX   = x + 4*s
    local totalW = w - 8*s
    local nChunks = math.floor((totalW + gap) / (chunkW + gap))
    local filled  = math.Round((stamina / MAX) * nChunks)

    for i = 0, nChunks - 1 do
        local cx = barX + i * (chunkW + gap)
        if i < filled then
            surface.SetDrawColor(col.r, col.g, col.b, 200)
        else
            surface.SetDrawColor(col.r, col.g, col.b, 40)
        end
        surface.DrawRect(cx, barY, chunkW, chunkH)
    end
end

-- Replace suit power bar
local col = EHUD.GetColumn("suitpower")
if col then
    col.base_element = elem
end
]==])

Player({{ID}}):ChatPrint("Stamina bar active. Sprinting drains it, stopping regens it.")
