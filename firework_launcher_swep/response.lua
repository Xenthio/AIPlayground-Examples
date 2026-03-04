RunSharedLua([[
local SWEPName = "weapon_firework_gun"

local SWEP = {} -- Initialize the SWEP table
SWEP.PrintName = "Firework Gun"
SWEP.Author = "Gilb"
SWEP.Instructions = "Left Click to launch a random color firework!"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Category = "Claude Weapons"

SWEP.Primary = {}
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 0.3 -- Slightly faster for more fun

SWEP.Secondary = {}
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Weight = 5
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false

SWEP.Slot = 1
SWEP.SlotPos = 2
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.ViewModel = "models/weapons/c_pistol.mdl"
SWEP.WorldModel = "models/weapons/w_pistol.mdl"
SWEP.UseHands = true

local FIREWORK_COLORS = {
    Color(255, 50, 50),   -- Red
    Color(50, 255, 50),   -- Green
    Color(50, 50, 255),   -- Blue
    Color(255, 255, 50),  -- Yellow
    Color(255, 50, 255),  -- Magenta
    Color(50, 255, 255),  -- Cyan
    Color(255, 255, 255), -- White
    Color(255, 128, 0),   -- Orange
    Color(128, 0, 255)    -- Purple
}

function SWEP:Initialize()
    self:SetHoldType("pistol")
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
    self:ShootEffects()

    if SERVER then
        local owner = self:GetOwner()
        if not IsValid(owner) then return end

        local ent = ents.Create("prop_physics")
        if not IsValid(ent) then return end

        ent:SetModel("models/Items/AR2_Grenade.mdl")
        ent:SetPos(owner:GetShootPos() + owner:GetForward() * 20)
        ent:SetAngles(owner:EyeAngles())
        ent:Spawn()

        ent:SetCollisionGroup(COLLISION_GROUP_PROJECTILE)
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetVelocity(owner:GetAimVector() * 1500)
        end

        -- Pick a random color for THIS shot
        local col = table.Random(FIREWORK_COLORS)

        -- Explosion timer
        timer.Simple(1.0, function()
            if IsValid(ent) then
                local pos = ent:GetPos()
                
                -- Effect
                local effectdata = EffectData()
                effectdata:SetOrigin(pos)
                effectdata:SetStart(Vector(col.r, col.g, col.b))
                util.Effect("AI_Firework_Explosion", effectdata)

                -- Sound
                ent:EmitSound("ambient/fire/mtl_fire_large_01.wav", 100, 100)
                ent:EmitSound("weapons/mortar/mortar_explode2.wav", 100, 100)

                ent:Remove()
            end
        end)
    end
end

function SWEP:SecondaryAttack()
    -- Secondary attack doesn't do anything special now since it's randomized
end

-- CUSTOM EFFECT WITH MOTION BLUR TRAILS
if CLIENT then
    local EFFECT = {}

    function EFFECT:Init(data)
        local pos = data:GetOrigin()
        local colVec = data:GetStart()
        local col = Color(colVec.x, colVec.y, colVec.z)

        local emitter = ParticleEmitter(pos)
        if not emitter then return end

        -- Central Flash
        for i = 1, 5 do
            local p = emitter:Add("sprites/glow04_noz", pos)
            if p then
                p:SetDieTime(0.2)
                p:SetStartAlpha(255)
                p:SetEndAlpha(0)
                p:SetStartSize(64)
                p:SetEndSize(128)
                p:SetColor(col.r, col.g, col.b)
            end
        end

        -- The Sparks (with perceived motion blur/trails)
        for i = 1, 60 do
            local p = emitter:Add("effects/spark", pos)
            if p then
                local vel = VectorRand() * 600
                p:SetVelocity(vel)
                p:SetDieTime(math.Rand(1, 2))
                p:SetStartAlpha(255)
                p:SetEndAlpha(0)
                
                -- Motion Blur Effect: Stretching the particle along its velocity
                p:SetStartLength(25) 
                p:SetEndLength(0) 
                
                p:SetStartSize(4)
                p:SetEndSize(0)
                
                p:SetColor(col.r, col.g, col.b)
                
                p:SetGravity(Vector(0, 0, -400))
                p:SetAirResistance(50)
                p:SetCollide(true)
                p:SetBounce(0.5)
            end
        end

        emitter:Finish()
    end

    function EFFECT:Think() return false end
    function EFFECT:Render() end

    effects.Register(EFFECT, "AI_Firework_Explosion")
end

weapons.Register(SWEP, "weapon_firework_gun")
]])
Player({{ID}}):ChatPrint("Firework SWEP has been made!")