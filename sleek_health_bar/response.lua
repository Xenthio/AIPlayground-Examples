-- PLAN: CLIENT, Draw a sleek, animated health bar overlay using EHUD framework.
-- Visual appearance unchanged. Now registered as health column base_element so
-- EHUD knows the allocated space and can correctly offset any vstack items above it.
RunClientLua([==[
if not EHUD then include("autorun/client/cl_extensible_hud.lua") end

local lerpHealth = 0
local BAR_W   = 300
local BAR_H   = 25
local ARMOR_H = 6
local ARMOR_GAP = 5

-- Hide default health/suit HUD
hook.Add("HUDShouldDraw", "HideDefaultHealth", function(name)
    if name == "CHudHealth" or name == "CHudBattery" then return false end
end)

-- EHUD element: size tells the framework how much space this takes so vstack
-- items above it are positioned correctly.
local elem = {}

function elem:GetSize()
    local ply = LocalPlayer()
    local hasArmor = IsValid(ply) and ply:Armor() > 0
    local h = BAR_H + 18  -- bar + "HEALTH" label above
    if hasArmor then h = h + ARMOR_GAP + ARMOR_H end
    return BAR_W, h
end

function elem:Draw(x, y, clip_h)
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local hp    = math.Clamp(ply:Health(), 0, ply:GetMaxHealth())
    local maxHp = ply:GetMaxHealth()
    lerpHealth  = Lerp(FrameTime() * 10, lerpHealth, hp)

    -- "HEALTH" label sits above the bar
    local labelY = y
    local barY   = y + 18

    -- Background Shadow
    surface.SetDrawColor(0, 0, 0, 150)
    surface.DrawRect(x + 2, barY + 2, BAR_W, BAR_H)

    -- Background Bar
    surface.SetDrawColor(40, 40, 40, 220)
    surface.DrawRect(x, barY, BAR_W, BAR_H)

    -- Dynamic Color (Green to Red)
    local hpRatio = lerpHealth / maxHp
    local barColor = Color((1 - hpRatio) * 255, hpRatio * 255, 100)

    -- Health Bar Fill
    surface.SetDrawColor(barColor.r, barColor.g, barColor.b, 200)
    surface.DrawRect(x, barY, BAR_W * hpRatio, BAR_H)

    -- Glass/Gradient Overlay
    surface.SetDrawColor(255, 255, 255, 30)
    surface.DrawRect(x, barY, BAR_W * hpRatio, BAR_H * 0.4)

    -- Text
    draw.SimpleTextOutlined(hp .. " / " .. maxHp, "DermaDefaultBold",
        x + BAR_W / 2, barY + BAR_H / 2,
        Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
        1, Color(0, 0, 0, 200))

    -- "HEALTH" label
    draw.SimpleText("HEALTH", "DermaDefault", x, labelY,
        Color(255, 255, 255, 200), TEXT_ALIGN_LEFT)

    -- Armor bar
    local armor = ply:Armor()
    if armor > 0 then
        local armorY = barY + BAR_H + ARMOR_GAP
        surface.SetDrawColor(0, 0, 0, 150)
        surface.DrawRect(x, armorY, BAR_W, ARMOR_H)
        surface.SetDrawColor(0, 150, 255, 200)
        surface.DrawRect(x, armorY, BAR_W * (armor / 100), ARMOR_H)
    end

    return BAR_W, clip_h
end

-- Register as health column base_element
local hCol = EHUD.GetColumn("health")
if hCol then
    hCol.width_base = BAR_W  -- tell EHUD the column is 300px wide
    hCol.base_element = elem
end
]==])

Player({{ID}}):ChatPrint("Sleek health bar active.")
