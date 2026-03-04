-- PLAN: CLIENT, add an oxygen meter to the EHUD right column.
-- Only visible when underwater (WaterLevel >= 3). Uses AddToColumn / RemoveFromColumn
-- to dynamically add/remove itself so it doesn't take up space when not needed.
-- NOTE: EHUD.AddToColumn adds an element to a column's vstack.
--       EHUD.RemoveFromColumn removes it cleanly (do NOT pass nil as the obj).
if SERVER then return end

RunClientLua([==[
local A = HL2Hud.Anim

local state = {
    fgColor = A.make(HL2Hud.Colors.FgColor),
    fgGlow  = A.make(Color(0,0,0,0)),
}

hook.Add("HL2Hud_ColorsChanged", "OxygenHud_Colors", function()
    A.snap(state.fgColor, HL2Hud.Colors.FgColor)
end)

local inColumn  = false
local lastOxygen = -1

local elem = {}

function elem:GetSize()
    local s = ScrH() / 480
    return 136*s, 36*s
end

function elem:Draw(x, y)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    A.step(state.fgColor)
    A.step(state.fgGlow)

    local oxygen = math.Clamp(ply:GetNWInt("Oxygen", 100), 0, 100)

    -- Flash red when low
    if oxygen ~= lastOxygen then
        lastOxygen = oxygen
        local C = HL2Hud.Colors
        if oxygen < 25 then
            A.set(state.fgColor, C.DamagedFg, "Linear", 0, 0.1)
        else
            A.set(state.fgColor, C.FgColor,   "Linear", 0, 0.2)
        end
    end

    HL2Hud.DrawNumericDisplay(x, y, "OXYGEN", oxygen, state, { label = "%" })
end

-- Register right column (ammo column already exists; this stacks above it)
EHUD.RegisterRightColumn("oxygen", 136, nil, 5)

hook.Add("Think", "OxygenHud_Toggle", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local underwater = ply:WaterLevel() >= 3

    if underwater and not inColumn then
        EHUD.AddToColumn("oxygen", "oxygen_meter", elem, 1)
        inColumn = true
    elseif not underwater and inColumn then
        EHUD.RemoveFromColumn("oxygen", "oxygen_meter")
        inColumn = false
    end
end)

-- GMod tracks oxygen as a player variable — hook into damage to update it
hook.Add("EntityTakeDamage", "OxygenHud_Track", function(ent, dmginfo)
    if ent ~= LocalPlayer() then return end
    if dmginfo:IsDamageType(DMG_DROWN) then
        local ply = LocalPlayer()
        local cur = ply:GetNWInt("Oxygen", 100)
        ply:SetNWInt("Oxygen", math.max(0, cur - 10))
    end
end)

-- Reset on surface
hook.Add("Think", "OxygenHud_Regen", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if ply:WaterLevel() < 3 then
        local cur = ply:GetNWInt("Oxygen", 100)
        if cur < 100 then
            ply:SetNWInt("Oxygen", math.min(100, cur + FrameTime() * 20))
        end
    end
end)
]==])

Player({{ID}}):ChatPrint("Oxygen HUD active — appears in right column when underwater.")
