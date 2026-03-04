
-- PLAN: Create a Shared SWEP using models/weapons/c_stunstick.mdl. 
-- Projectiles: Custom ENT "ent_rainbow_bolt" with Sine-wave physics on Server and Rainbow particle trails on Client.
-- Cleanup: SafeRemoveEntityDelayed for projectiles, Kill emitters on finish.

RunSharedLua([[
local SWEP_CLASS = "weapon_rainbow_wand"

local SWEP = {}
SWEP.PrintName = "Rainbow Wand"
SWEP.Author = "Gilb"
SWEP.Instructions = "Left Click to fire a chaotic rainbow bolt!"
SWEP.Spawnable = true
SWEP.Category = "Claude Weapons"
SWEP.Slot = 1
SWEP.SlotPos = 1

SWEP.ViewModel = "models/weapons/c_stunstick.mdl"
SWEP.WorldModel = "models/weapons/w_stunbaton.mdl"
SWEP.UseHands = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 0.15

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

function SWEP:Initialize()
    self:SetHoldType("melee")
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
    self:SendWeaponAnim(ACT_VM_HITCENTER)
    self:EmitSound("weapons/stunstick/stunstick_swing1.wav", 75, math.random(150, 200))

    if SERVER then
        local owner = self:GetOwner()
        if not IsValid(owner) then return end

        local bolt = ents.Create("ent_rainbow_bolt")
        if not IsValid(bolt) then return end

        local screenTrace = owner:GetEyeTrace()
        bolt:SetPos(owner:GetShootPos() + owner:GetForward() * 20 + owner:GetUp() * -5)
        bolt:SetAngles(owner:EyeAngles())
        bolt:SetOwner(owner)
        bolt:Spawn()

        local phys = bolt:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetVelocity(owner:GetAimVector() * 1200)
        end
    end
end

function SWEP:SecondaryAttack() end

-- PROJECTILE ENTITY
local BOLT_ENT = {}
BOLT_ENT.Type = "anim"
BOLT_ENT.Base = "base_anim"

if SERVER then
    function BOLT_ENT:Initialize()
        self:SetModel("models/Items/AR2_Grenade.mdl")
        self:SetNoDraw(true)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetCollisionGroup(COLLISION_GROUP_PROJECTILE)
        
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
            phys:EnableGravity(false)
            phys:SetMass(1)
        end

        self.SpawnTime = CurTime()
        self.RandomSeed = math.random(0, 100)
        SafeRemoveEntityDelayed(self, 3)
    end

    function BOLT_ENT:PhysicsUpdate(phys)
        local time = CurTime() - self.SpawnTime
        -- Chaotic curving logic
        local forward = self:GetForward()
        local up = self:GetUp()
        local right = self:GetRight()
        
        local waveX = math.sin(time * 15 + self.RandomSeed) * 400
        local waveY = math.cos(time * 12 + self.RandomSeed) * 400
        
        phys:SetVelocity(forward * 1300 + up * waveX + right * waveY)
    end

    function BOLT_ENT:PhysicsCollide(data, phys)
        local pos = data.HitPos
        
        local explode = ents.Create("env_explosion")
        explode:SetPos(pos)
        explode:SetOwner(self:GetOwner())
        explode:SetKeyValue("iMagnitude", "50")
        explode:Spawn()
        explode:Fire("Explode", 0, 0)

        -- Visual effect trigger
        local ed = EffectData()
        ed:SetOrigin(pos)
        ed:SetScale(1)
        util.Effect("cball_explode", ed)

        self:Remove()
    end
end

if CLIENT then
    function BOLT_ENT:Initialize()
        self.Emitter = ParticleEmitter(self:GetPos())
    end

    function BOLT_ENT:Think()
        if not IsValid(self.Emitter) then return end
        
        local pos = self:GetPos()
        local hue = (CurTime() * 300) % 360
        local col = HSVToColor(hue, 1, 1)

        for i = 1, 3 do
            local p = self.Emitter:Add("particle/particle_glow_05", pos + VectorRand() * 5)
            if p then
                p:SetDieTime(0.4)
                p:SetStartAlpha(255)
                p:SetEndAlpha(0)
                p:SetStartSize(15)
                p:SetEndSize(0)
                p:SetColor(col.r, col.g, col.b)
                p:SetVelocity(self:GetVelocity() * -0.2 + VectorRand() * 20)
            end
        end
    end

    function BOLT_ENT:OnRemove()
        if IsValid(self.Emitter) then
            self.Emitter:Finish()
        end
    end
end

scripted_ents.Register(BOLT_ENT, "ent_rainbow_bolt")
weapons.Register(SWEP, SWEP_CLASS)
]])

Player(2):ChatPrint("Rainbow Wand created! Check the Claude Weapons category.")
