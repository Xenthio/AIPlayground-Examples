RunSharedLua([[
SWEP = {Primary = {}, Secondary = {}}
SWEP.Base = "weapon_base"
SWEP.PrintName = "Minecraft Builder"
SWEP.Author = "Claude"
SWEP.Category = "Claude Weapons"
SWEP.Spawnable = true
SWEP.Slot = 5
SWEP.SlotPos = 1
SWEP.ViewModel = "models/weapons/c_toolgun.mdl"
SWEP.WorldModel = "models/weapons/w_toolgun.mdl"
SWEP.Primary = { ClipSize = -1, DefaultClip = -1, Automatic = false, Ammo = "none" }
SWEP.Secondary = { ClipSize = -1, DefaultClip = -1, Automatic = false, Ammo = "none" }
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false

local BLOCK_SIZE = 48
local HALF = BLOCK_SIZE / 2
local BLOCK_COLORS = {
    {name = "Grass",    col = Color(95, 159, 53)},
    {name = "Dirt",     col = Color(134, 96, 67)},
    {name = "Stone",    col = Color(125, 125, 125)},
    {name = "Oak Wood", col = Color(102, 76, 40)},
    {name = "Cobble",   col = Color(100, 100, 100)},
    {name = "Sand",     col = Color(219, 207, 163)},
    {name = "Oak Plank",col = Color(188, 152, 98)},
    {name = "Brick",    col = Color(150, 97, 83)},
    {name = "Glass",    col = Color(200, 220, 255)},
    {name = "Gold",     col = Color(255, 215, 0)},
}

local NEIGHBORS = {
    Vector(BLOCK_SIZE, 0, 0), Vector(-BLOCK_SIZE, 0, 0),
    Vector(0, BLOCK_SIZE, 0), Vector(0, -BLOCK_SIZE, 0),
    Vector(0, 0, BLOCK_SIZE), Vector(0, 0, -BLOCK_SIZE),
}

if CLIENT then
    SWEP._blockIndex = 1
    SWEP._scrollCooldown = 0
end

function SWEP:Initialize()
    self:SetHoldType("slam")
    if CLIENT then
        self._blockIndex = 1
        self._scrollCooldown = 0
    end
end

function SWEP:SetupDataTables()
    self:NetworkVar("Int", 0, "BlockType")
    if SERVER then self:SetBlockType(1) end
end

local function SnapToGrid(pos)
    return Vector(
        math.floor(pos.x / BLOCK_SIZE + 0.5) * BLOCK_SIZE,
        math.floor(pos.y / BLOCK_SIZE + 0.5) * BLOCK_SIZE,
        math.floor(pos.z / BLOCK_SIZE + 0.5) * BLOCK_SIZE
    )
end

local function PosKey(pos)
    return math.Round(pos.x) .. "," .. math.Round(pos.y) .. "," .. math.Round(pos.z)
end

local function SnapNormal(hitNormal)
    local absX, absY, absZ = math.abs(hitNormal.x), math.abs(hitNormal.y), math.abs(hitNormal.z)
    if absX >= absY and absX >= absZ then
        return Vector(hitNormal.x > 0 and 1 or -1, 0, 0)
    elseif absY >= absX and absY >= absZ then
        return Vector(0, hitNormal.y > 0 and 1 or -1, 0)
    else
        return Vector(0, 0, hitNormal.z > 0 and 1 or -1)
    end
end

if SERVER then
    util.AddNetworkString("mc_place_block")
    util.AddNetworkString("mc_remove_block")

    MC_Blocks = MC_Blocks or {}

    local function IsOverlapping(pos)
        local blockMins = pos - Vector(HALF, HALF, HALF)
        local blockMaxs = pos + Vector(HALF, HALF, HALF)
        for _, ply in ipairs(player.GetAll()) do
            local plyMins = ply:GetPos() + ply:OBBMins()
            local plyMaxs = ply:GetPos() + ply:OBBMaxs()
            if blockMins.x < plyMaxs.x and blockMaxs.x > plyMins.x and
               blockMins.y < plyMaxs.y and blockMaxs.y > plyMins.y and
               blockMins.z < plyMaxs.z and blockMaxs.z > plyMins.z then
                return true
            end
        end
        return false
    end

    local function WeldToNeighbors(pos, ent)
        for _, offset in ipairs(NEIGHBORS) do
            local neighborKey = PosKey(pos + offset)
            local neighborData = MC_Blocks[neighborKey]
            if neighborData and IsValid(neighborData.ent) then
                constraint.Weld(ent, neighborData.ent, 0, 0, 0, true, false)
            end
        end
    end

    local function CreateBlock(pos, blockType, key)
        local ent = ents.Create("prop_physics")
        if not IsValid(ent) then return nil end
        ent:SetModel("models/hunter/blocks/cube1x1x1.mdl")
        ent:SetPos(pos)
        ent:SetAngles(Angle(0, 0, 0))
        ent:SetColor(BLOCK_COLORS[blockType].col)
        ent:SetMaterial("models/debug/debugwhite")
        ent:Spawn()
        ent:Activate()

        ent:SetModelScale(1.02, 0)

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
            phys:SetMass(50000)
        end
        ent:SetMoveType(MOVETYPE_PUSH)

        ent:DrawShadow(false)
        ent.IsMCBlock = true
        ent.MCBlockKey = key
        ent.MCBlockType = blockType

        MC_Blocks[key] = {pos = pos, blockType = blockType, ent = ent}

        WeldToNeighbors(pos, ent)

        return ent
    end

    local function RemoveBlock(key)
        local data = MC_Blocks[key]
        if not data then return end
        if IsValid(data.ent) then
            constraint.RemoveAll(data.ent)
            data.ent:Remove()
        end
        MC_Blocks[key] = nil
    end

    local function TraceForBlock(ply)
        local tr = util.TraceLine({
            start = ply:EyePos(),
            endpos = ply:EyePos() + ply:GetAimVector() * 600,
            filter = ply
        })
        if not tr.Hit then return nil end
        return tr
    end

    net.Receive("mc_place_block", function(_, ply)
        local blockType = net.ReadUInt(8)
        if blockType < 1 or blockType > #BLOCK_COLORS then return end

        local tr = TraceForBlock(ply)
        if not tr then return end

        local placePos
        if IsValid(tr.Entity) and tr.Entity.IsMCBlock then
            local data = MC_Blocks[tr.Entity.MCBlockKey]
            if not data then return end
            local snappedNormal = SnapNormal(tr.HitNormal)
            placePos = data.pos + snappedNormal * BLOCK_SIZE
        else
            placePos = SnapToGrid(tr.HitPos + tr.HitNormal * (HALF * 0.5))
        end

        local key = PosKey(placePos)
        if MC_Blocks[key] then return end
        if IsOverlapping(placePos) then return end
        if placePos:Distance(ply:EyePos()) > 650 then return end

        CreateBlock(placePos, blockType, key)
        ply:EmitSound("physics/concrete/concrete_block_impact_hard" .. math.random(2, 3) .. ".wav", 60, math.random(90, 110))
    end)

    net.Receive("mc_remove_block", function(_, ply)
        local tr = TraceForBlock(ply)
        if not tr then return end
        if not IsValid(tr.Entity) or not tr.Entity.IsMCBlock then return end
        local key = tr.Entity.MCBlockKey
        if not key then return end
        RemoveBlock(key)
        ply:EmitSound("physics/concrete/concrete_break2.wav", 60, math.random(90, 120))
    end)
end

if CLIENT then
    -- Only block scroll-based weapon switching, allow number keys
    hook.Add("PlayerBindPress", "mc_block_scroll_switch", function(ply, bind, pressed)
        if not IsValid(ply) then return end
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "mc_builder" then return end
        if bind == "invprev" or bind == "invnext" then
            return true
        end
    end)

    hook.Add("CreateMove", "mc_scroll_capture", function(cmd)
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "mc_builder" then return end

        local scroll = cmd:GetMouseWheel()
        if scroll ~= 0 and RealTime() > (wep._scrollCooldown or 0) then
            wep._blockIndex = wep._blockIndex or 1
            if scroll > 0 then
                wep._blockIndex = wep._blockIndex - 1
            else
                wep._blockIndex = wep._blockIndex + 1
            end
            if wep._blockIndex < 1 then wep._blockIndex = #BLOCK_COLORS end
            if wep._blockIndex > #BLOCK_COLORS then wep._blockIndex = 1 end
            wep._scrollCooldown = RealTime() + 0.15
            surface.PlaySound("ui/buttonrollover.wav")
        end
    end)

    hook.Add("PostDrawOpaqueRenderables", "mc_draw_overlays", function(isDrawingDepth, isDrawingSkybox)
        if isDrawingSkybox or isDrawingDepth then return end
        local ply = LocalPlayer()
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "mc_builder" then return end

        local tr = ply:GetEyeTrace()
        if not tr.Hit or tr.HitPos:Distance(ply:EyePos()) > 600 then return end

        local bt = wep._blockIndex or 1
        local bc = BLOCK_COLORS[bt] or BLOCK_COLORS[1]

        -- Red outline on removal target
        if IsValid(tr.Entity) and tr.Entity.IsMCBlock then
            local entPos = tr.Entity:GetPos()
            local e = 0.5
            for i = 0, 2 do
                local off = i * 0.15
                render.DrawWireframeBox(entPos, Angle(0,0,0),
                    Vector(-HALF - e - off, -HALF - e - off, -HALF - e - off),
                    Vector(HALF + e + off, HALF + e + off, HALF + e + off),
                    Color(255, 50, 50, 255), false)
            end
        end

        -- Ghost placement preview
        local placePos
        if IsValid(tr.Entity) and tr.Entity.IsMCBlock then
            local snappedNormal = SnapNormal(tr.HitNormal)
            placePos = tr.Entity:GetPos() + snappedNormal * BLOCK_SIZE
        else
            placePos = SnapToGrid(tr.HitPos + tr.HitNormal * (HALF * 0.5))
        end

        if placePos then
            local ghostCol = ColorAlpha(bc.col, 80)
            render.SetColorMaterial()
            render.DrawBox(placePos, Angle(0,0,0), Vector(-HALF,-HALF,-HALF), Vector(HALF,HALF,HALF), ghostCol, true)

            local e = 0.3
            for i = 0, 2 do
                local off = i * 0.15
                render.DrawWireframeBox(placePos, Angle(0,0,0),
                    Vector(-HALF - e - off, -HALF - e - off, -HALF - e - off),
                    Vector(HALF + e + off, HALF + e + off, HALF + e + off),
                    Color(255, 255, 255, 220), false)
            end
        end
    end)

    hook.Add("HUDPaint", "mc_builder_hud", function()
        local ply = LocalPlayer()
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "mc_builder" then return end

        local bt = wep._blockIndex or 1
        local bc = BLOCK_COLORS[bt]
        local sw, sh = ScrW(), ScrH()

        local cx, cy = sw / 2, sh / 2
        surface.SetDrawColor(255, 255, 255, 200)
        surface.DrawLine(cx - 10, cy, cx - 4, cy)
        surface.DrawLine(cx + 4, cy, cx + 10, cy)
        surface.DrawLine(cx, cy - 10, cx, cy - 4)
        surface.DrawLine(cx, cy + 4, cx, cy + 10)

        local barW = #BLOCK_COLORS * 44 + 8
        local barX = (sw - barW) / 2
        local barY = sh - 70

        draw.RoundedBox(6, barX, barY, barW, 52, Color(0, 0, 0, 160))

        for i, b in ipairs(BLOCK_COLORS) do
            local bx = barX + 6 + (i - 1) * 44
            local by = barY + 6
            if i == bt then
                draw.RoundedBox(4, bx - 2, by - 2, 44, 44, Color(255, 255, 255, 200))
            end
            draw.RoundedBox(2, bx, by, 40, 40, b.col)
            local darker = Color(b.col.r * 0.7, b.col.g * 0.7, b.col.b * 0.7)
            draw.RoundedBox(0, bx, by + 20, 40, 20, darker)
        end

        draw.SimpleTextOutlined(bc.name, "DermaDefaultBold", sw / 2, barY - 8, Color(255, 255, 255, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, 200))
        draw.SimpleTextOutlined("LMB: Place | RMB: Remove | Scroll: Select Block | 1-6: Switch Weapon", "DermaDefault", sw / 2, barY + 60, Color(200, 200, 200, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 150))
    end)
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 0.15)
    if CLIENT and IsFirstTimePredicted() then
        net.Start("mc_place_block")
            net.WriteUInt(self._blockIndex or 1, 8)
        net.SendToServer()
    end
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 0.15)
    if CLIENT and IsFirstTimePredicted() then
        net.Start("mc_remove_block")
        net.SendToServer()
    end
end

function SWEP:Holster() return true end
function SWEP:OnRemove() end

weapons.Register(SWEP, "mc_builder")
]])

Player(2):ChatPrint("Minecraft Builder SWEP registered! Find it in your spawn menu under Claude Weapons.")
Player(2):ChatPrint("LMB = Place Block | RMB = Remove Block | Scroll = Change Block | 1-6 = Switch Weapon")