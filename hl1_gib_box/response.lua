-- HL1 gibbing with accurate physics using hl1_hgib.
-- GilbUtils.Gibs.Explode handles all velocity and spawning for you, but we include the DIY logic just incase.

RunSharedLua([[
local ENT = {}
ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Gib Box (HL1)"
ENT.Author = "AI"
ENT.Category = "AI Creations"
ENT.Spawnable = true

function ENT:Initialize()
    self:SetModel("models/props_junk/wood_crate001a.mdl")
    if SERVER then
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetHealth(20)
        self:SetMaxHealth(20)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end
    end
end

if SERVER then
    function ENT:OnTakeDamage(dmg)
        self:SetHealth(self:Health() - dmg:GetDamage())
        if self:Health() <= 0 then self:Gib(dmg) end
        -- We could also use GilbUtils.Gibs.Explode(self, dmg) and use self:Remove()! it saves tokens!
    end

    function ENT:Gib(dmg)
        local obbMins = self:OBBMins()
        local obbSize = self:OBBMaxs() - obbMins

        local effectdata = EffectData()
        effectdata:SetOrigin(self:WorldSpaceCenter())
        effectdata:SetScale(1)
        util.Effect("BloodImpact", effectdata)
        self:EmitSound("common/bodysplat.wav")

        local health = self:Health()
        local velMul = health > -50 and 0.7 or (health > -200 and 2.0 or 4.0)

        -- attackDir: GetDamageForce in GMod points away from attacker (use directly, unlike HL1)
        local attackDir = dmg:GetDamageForce()
        if attackDir:LengthSqr() == 0 then attackDir = Vector(0, 0, -1) end
        attackDir:Normalize()

        -- Head gib at EyePos, 5% chance thrown toward nearest player
        local headGib = ents.Create("hl1_hgib")
        if IsValid(headGib) then
            headGib:SetNWInt("GibBodygroup", 0)
            headGib:Spawn()
            headGib:SetPos(self:EyePos())
            local ply = player.GetAll()[1]
            local vel
            if ply and math.random(1, 100) <= 5 then
                vel = ((ply:EyePos() - self:EyePos()):GetNormalized() * 300 + Vector(0, 0, 100)) * velMul
            else
                vel = Vector(math.Rand(-100, 100), math.Rand(-100, 100), math.Rand(200, 300)) * velMul
            end
            if vel:Length() > 1500 then vel = vel:GetNormalized() * 1500 end
            headGib.GibVelocity = vel
            headGib.AngVelocity = Angle(math.Rand(100, 200), math.Rand(100, 300), 0)
        end

        -- 4 body gibs at random points inside bounding box
        for i = 1, 4 do
            local gib = ents.Create("hl1_hgib")
            if IsValid(gib) then
                gib:SetNWInt("GibBodygroup", math.random(1, 5))
                gib:Spawn()
                gib:SetPos(self:GetPos() + obbMins + Vector(
                    obbSize.x * math.Rand(0, 1),
                    obbSize.y * math.Rand(0, 1),
                    obbSize.z * math.Rand(0, 1) + 1
                ))
                -- HL1: vel = (attackDir + noise) * RANDOM_FLOAT(300,400) * velMul
                local vel = attackDir + Vector(math.Rand(-0.25, 0.25), math.Rand(-0.25, 0.25), math.Rand(-0.25, 0.25))
                vel = vel * math.Rand(300, 400) * velMul
                if vel:Length() > 1500 then vel = vel:GetNormalized() * 1500 end
                gib.GibVelocity = vel
                gib.AngVelocity = Angle(math.Rand(100, 200), math.Rand(100, 300), 0)
            end
        end

        self:Remove()
    end
end

function ENT:Draw() self:DrawModel() end

scripted_ents.Register(ENT, "gib_test_box")
]])