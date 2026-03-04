-- PLAN: CLIENT, replace the suit power bar with a custom stamina bar.
-- Sets EHUD.GetColumn("suitpower").base_element to a chunked bar element.
-- Drains while sprinting, regens when standing still. Uses HL2Hud.Colors.
RunClientLua([==[
local C = HL2Hud.Colors

local stamina  = 100
local DRAIN    = 20   -- per second sprinting
local REGEN    = 10   -- per second not sprinting

hook.Add("HL2Hud_ColorsChanged", "StaminaBar_Colors", function()
    C = HL2Hud.Colors
end)

local elem = {}

function elem:GetSize()
    local s = ScrH() / 480
    return 102*s, 26*s
end

function elem:Draw(x, y)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    if ply:IsSprinting() then
        stamina = math.max(0,   stamina - DRAIN * FrameTime())
    else
        stamina = math.min(100, stamina + REGEN * FrameTime())
    end

    local s    = ScrH() / 480
    local low  = stamina < 25
    local col  = low and C.DamagedFg or C.FgColor
    local w, h = 102*s, 26*s

    HL2Hud.DrawPanel(x, y, w, h)

    draw.SimpleText("STAMINA", "HL2Hud_Text", x + 4*s, y + 3*s, col)

    -- Chunked bar matching hud_suit_power.lua geometry: 6px chunks, 3px gap
    local chunkW  = math.Round(6 * s)
    local chunkH  = math.Round(8 * s)
    local gap     = math.Round(3 * s)
    local barX    = x + 4*s
    local barY    = y + h - chunkH - 4*s
    local totalW  = w - 8*s
    local nChunks = math.floor((totalW + gap) / (chunkW + gap))
    local filled  = math.Round((stamina / 100) * nChunks)

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

local col = EHUD.GetColumn("suitpower")
if col then col.base_element = elem end
]==])
Player({{ID}}):ChatPrint("Stamina bar active. Sprinting drains it, stopping regens it.")
