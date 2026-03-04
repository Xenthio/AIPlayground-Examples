-- HL1 func_breakable-style wood crate using GilbUtils.
-- GilbUtils.Gibs.SpawnDebrisGib uses hl1_debris_gib: slow gravity, bounce, settle (TE_BREAKMODEL physics).
-- For combat gibs with blood use GilbUtils.Gibs.Explode / SpawnGib instead.

RunSharedLua([[
AddCSLuaFile()
local ENT = {}
ENT.Type      = "anim"
ENT.Base      = "base_gmodentity"
ENT.PrintName = "HL1 Breakable Crate"
ENT.Author    = "AI"
ENT.Category  = "AI Creations"
ENT.Spawnable = true

local WOOD_GIB_MODEL    = "models/woodgibs.mdl"
local CONTENT_GIB_MODEL = "models/med_crategibs.mdl"
local BUST_SOUNDS       = { "debris/bustcrate1.wav", "debris/bustcrate2.wav" }
local WOOD_SOUNDS       = { "debris/wood1.wav", "debris/wood2.wav", "debris/wood3.wav", "debris/wood4.wav" }

function ENT:Initialize()
    self:SetModel("models/props_junk/wood_crate001a.mdl")
    if SERVER then
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetHealth(30)
        self:SetMaxHealth(30)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end
    end
end

if SERVER then
    function ENT:OnTakeDamage(dmg)
        if math.random(1, 3) == 1 then
            self:EmitSound(WOOD_SOUNDS[math.random(#WOOD_SOUNDS)], 70, 100, math.Clamp(dmg:GetDamage() / 100, 0.2, 1.0))
        end
        self:SetHealth(self:Health() - dmg:GetDamage())
        if self:Health() <= 0 then self:Break(dmg) end
    end

    function ENT:Break(dmg)
        local obbMins = self:OBBMins()
        local obbSize = self:OBBMaxs() - obbMins
        local force    = dmg:GetDamageForce()
        local hasForce = force:LengthSqr() > 0
        local forceDir = hasForce and force:GetNormalized() or Vector(0, 0, 1)

        local pitch = math.random(95, 124)
        self:EmitSound(BUST_SOUNDS[math.random(#BUST_SOUNDS)], 80, pitch)

        -- Wood shards: TE_BREAKMODEL-style slow gravity + settle
        local randRange = 150
        for i = 1, math.random(5, 8) do
            local pos = self:GetPos() + obbMins + Vector(
                obbSize.x * math.Rand(0, 1),
                obbSize.y * math.Rand(0, 1),
                obbSize.z * math.Rand(0, 1) + 1
            )
            local vel = Vector(math.Rand(-randRange, randRange), math.Rand(-randRange, randRange), math.Rand(0, randRange))
            if hasForce then vel = vel + forceDir * 80 end
            GilbUtils.Gibs.SpawnDebrisGib(WOOD_GIB_MODEL, math.random(0, 6), pos, vel, 8)
        end

        -- Contents
        for i = 1, 3 do
            local pos = self:GetPos() + obbMins + Vector(
                obbSize.x * math.Rand(0.2, 0.8),
                obbSize.y * math.Rand(0.2, 0.8),
                obbSize.z * math.Rand(0.5, 1.0)
            )
            local vel = Vector(math.Rand(-100, 100), math.Rand(-100, 100), math.Rand(80, 250))
            GilbUtils.Gibs.SpawnDebrisGib(CONTENT_GIB_MODEL, math.random(0, 8), pos, vel, 12)
        end

        local effectdata = EffectData()
        effectdata:SetOrigin(self:WorldSpaceCenter())
        effectdata:SetScale(2)
        util.Effect("WoodImpact", effectdata)

        self:Remove()
    end
end

function ENT:Draw() self:DrawModel() end

scripted_ents.Register(ENT, "hl1_breakable_crate")
]])