-- PLAN: CLIENT, replace health/suit panels with a cyber-style display.
-- Replaces EHUD base_element on health and suit columns directly.
-- Restore with: EHUD.GetColumn("health").base_element = HL2Hud.healthElem
--               EHUD.GetColumn("suit").base_element   = HL2Hud.suitElem
RunClientLua([==[
local lerpHP    = 0
local lerpArmor = 0
local lastHP    = -1
local damageFlash = 0

local healthElem = {}
function healthElem:GetSize()
    local s = ScrH() / 480
    return 160*s, 40*s
end

function healthElem:Draw(x, y, clip_h)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local s     = ScrH() / 480
    local hp    = ply:Health()
    local maxHP = math.max(1, ply:GetMaxHealth())
    local armor = ply:Armor()

    if lastHP == -1 then lastHP = hp end
    if hp < lastHP then damageFlash = 1 end
    lastHP = hp
    damageFlash = math.Approach(damageFlash, 0, FrameTime() * 2)

    lerpHP    = Lerp(FrameTime() * 8, lerpHP,    hp)
    lerpArmor = Lerp(FrameTime() * 8, lerpArmor, armor)

    local w, h = 160*s, 40*s
    local C = HL2Hud.Colors
    local hpCol = (hp <= 25) and C.DamagedFg or C.FgColor

    -- Background
    draw.RoundedBox(0, x, y, w, h, Color(0, 0, 0, 150))
    surface.SetDrawColor(C.FgColor.r, C.FgColor.g, C.FgColor.b,
                         50 + damageFlash * 100)
    surface.DrawOutlinedRect(x, y, w, h, math.max(1, math.Round(s)))

    -- Health number + label
    draw.SimpleText(math.ceil(lerpHP), "HL2Hud_NumbersSmall",
                    x + 6*s, y + 4*s, hpCol, TEXT_ALIGN_LEFT)
    draw.SimpleText("VITAL SIGNS", "HL2Hud_Text",
                    x + 6*s, y + 22*s, hpCol, TEXT_ALIGN_LEFT)

    -- Segmented vertical bar
    local segments = 10
    local barX = x + 90*s
    local barY = y + 4*s
    local barW = 8*s
    local barH = 32*s
    for i = 0, segments - 1 do
        local segY = barY + (barH / segments) * (segments - 1 - i)
        local segH = math.floor(barH / segments) - s
        local threshold = (i / segments) * maxHP
        surface.SetDrawColor(lerpHP > threshold
            and Color(hpCol.r, hpCol.g, hpCol.b, 255)
            or  Color(40, 40, 40, 200))
        surface.DrawRect(barX, segY, barW, segH)
    end

    -- Armor readout (right side)
    if armor > 0 then
        local armX = x + 108*s
        local auxCol = C.AuxHigh
        draw.SimpleText(math.ceil(lerpArmor), "HL2Hud_NumbersSmall",
                        armX, y + 4*s, auxCol, TEXT_ALIGN_LEFT)
        draw.SimpleText("DEFENSE", "HL2Hud_Text",
                        armX, y + 22*s, auxCol, TEXT_ALIGN_LEFT)
        surface.SetDrawColor(auxCol)
        surface.DrawRect(armX, y + 30*s, 40*s * (lerpArmor / 100), 2*s)
    end

    -- Glitch flash on damage
    if damageFlash > 0.1 then
        draw.RoundedBox(0,
            x - damageFlash * 6*s, y,
            math.Round(2*s), h,
            Color(255, 255, 255, 200 * damageFlash))
    end

    return w, h
end

-- Suit column: hide (armor is shown inside healthElem above)
local suitElem = {}
function suitElem:GetSize() local s=ScrH()/480 return 108*s, 0 end
function suitElem:Draw() end

local hCol = EHUD.GetColumn("health")
local sCol = EHUD.GetColumn("suit")
if hCol then hCol.base_element = healthElem end
if sCol then sCol.base_element = suitElem   end
]==])
Player({{ID}}):ChatPrint("Cyber health HUD active. To restore: lua EHUD.GetColumn('health').base_element = HL2Hud.healthElem")
