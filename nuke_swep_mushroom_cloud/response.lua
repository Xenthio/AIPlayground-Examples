
-- REALM: SHARED
-- DESCRIPTION: A Nuke SWEP that launches a projectile, creating a massive mushroom cloud and a devastating explosion.
-- CLEANUP: Projectiles and particles clean themselves up.

RunSharedLua([[
local SWEP_NAME = "weapon_gilb_nuke"
local SWEP = {Primary = {}, Secondary = {}}
SWEP.PrintName = "Tactical Nuke"
SWEP.Author = "Gilb"
SWEP.Category = "Claude Weapons"
SWEP.Spawnable = true
SWEP.Slot = 4
SWEP.SlotPos = 1
SWEP.ViewModel = "models/weapons/c_rpg.mdl"
SWEP.WorldModel = "models/weapons/w_rocket_launcher.mdl"
SWEP.UseHands = true
SWEP.HoldType = "rpg"

SWEP.Primary = { 
    ClipSize = 1, 
    DefaultClip = 5, 
    Automatic = false, 
    Ammo = "RPG_Round", 
    Delay = 5.0 
}
SWEP.Secondary = { ClipSize = -1, DefaultClip = -1, Automatic = false, Ammo = "none" }

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
    
    if SERVER then
        local owner = self:GetOwner()
        local ent = ents.Create("prop_physics")
        if not IsValid(ent) then return end

        ent:SetModel("models/Items/AR2_Grenade.mdl")
        ent:SetPos(owner:GetShootPos() + owner:GetForward() * 32)
        ent:SetAngles(owner:EyeAngles())
        ent:SetOwner(owner)
        ent:Spawn()
        
        ent:SetModelScale(2, 0)
        ent:SetRenderMode(RENDERMODE_TRANSALPHA)
        ent:SetColor(Color(255, 100, 0, 255))

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetVelocity(owner:GetAimVector() * 2000)
            phys:EnableGravity(false)
        end

        -- Detonation logic
        local function Detonate(projectile)
            if not IsValid(projectile) then return end
            local pos = projectile:GetPos()
            
            -- Massive Explosion Effect
            local ed = EffectData()
            ed:SetOrigin(pos)
            ed:SetScale(1)
            util.Effect("GilbNukeExplosion", ed)

            -- Damage & Physics Blast
            util.ScreenShake(pos, 50, 5, 10, 5000)
            util.BlastDamage(projectile, owner, pos, 2500, 1000)
            
            -- Push everything away
            for _, victim in ipairs(ents.FindInSphere(pos, 3000)) do
                local vphys = victim:GetPhysicsObject()
                if IsValid(vphys) then
                    local dir = (victim:GetPos() - pos):GetNormalized()
                    vphys:ApplyForceCenter(dir * 500000)
                end
            end

            projectile:EmitSound("ambient/explosions/explode_4.wav", 150, 70)
            projectile:EmitSound("ambient/levels/canals/headcrab_canister_explosion.wav", 150, 100)
            
            projectile:Remove()
        end

        ent:SetCollisionGroup(COLLISION_GROUP_PROJECTILE)
        local has_hit = false
        ent:AddCallback("PhysicsCollide", function()
            if has_hit then return end
            has_hit = true
            Detonate(ent)
        end)
        
        -- Fail-safe timer
        timer.Simple(10, function() if IsValid(ent) then Detonate(ent) end end)

        self:TakePrimaryAmmo(1)
        self:EmitSound("weapons/launcher_fire.wav", 100, 100)
    end
end

function SWEP:SecondaryAttack() end

if CLIENT then
    local EFFECT = {}

    function EFFECT:Init(data)
        local pos = data:GetOrigin()
        local emitter = ParticleEmitter(pos, false)
        if not emitter then return end

        -- 1. GROUND FLASH & SHOCKWAVE
        for i = 1, 30 do
            local p = emitter:Add("sprites/glow04_noz", pos)
            if p then
                p:SetDieTime(math.Rand(0.5, 1.5))
                p:SetStartAlpha(255)
                p:SetEndAlpha(0)
                p:SetStartSize(100)
                p:SetEndSize(4000)
                p:SetColor(255, 200, 150)
            end
        end

        -- 2. MUSHROOM STEM
        for i = 1, 100 do
            local p = emitter:Add("particles/smokey", pos + Vector(0,0, i * 15))
            if p then
                p:SetDieTime(math.Rand(5, 8))
                p:SetStartAlpha(math.Rand(150, 200))
                p:SetEndAlpha(0)
                p:SetStartSize(math.Rand(100, 200))
                p:SetEndSize(math.Rand(400, 600))
                p:SetRoll(math.Rand(-180, 180))
                p:SetRollDelta(math.Rand(-0.2, 0.2))
                p:SetColor(60, 60, 60)
                p:SetGravity(Vector(0, 0, 100))
                p:SetAirResistance(20)
            end
        end

        -- 3. MUSHROOM CAP
        local capPos = pos + Vector(0, 0, 1500)
        for i = 1, 200 do
            local ringPos = VectorRand() * 800
            ringPos.z = math.Rand(-200, 200)
            
            local p = emitter:Add("particles/smokey", capPos + ringPos)
            if p then
                p:SetVelocity(ringPos:GetNormalized() * 500)
                p:SetDieTime(math.Rand(8, 12))
                p:SetStartAlpha(200)
                p:SetEndAlpha(0)
                p:SetStartSize(math.Rand(300, 500))
                p:SetEndSize(math.Rand(800, 1200))
                p:SetRoll(math.Rand(-180, 180))
                p:SetColor(80, 70, 60)
                p:SetAirResistance(50)
            end
        end
        
        -- 4. FIRE CORE
        for i = 1, 40 do
            local p = emitter:Add("sprites/light_ignorez", capPos + VectorRand()*200)
            if p then
                p:SetDieTime(math.Rand(2, 4))
                p:SetStartAlpha(255)
                p:SetEndAlpha(0)
                p:SetStartSize(500)
                p:SetEndSize(1500)
                p:SetColor(255, 100, 0)
            end
        end

        emitter:Finish()
        
        -- Screen flash
        local dlight = DynamicLight(0)
        if dlight then
            dlight.pos = pos
            dlight.r = 255
            dlight.g = 150
            dlight.b = 50
            dlight.brightness = 10
            dlight.Decay = 1000
            dlight.Size = 8000
            dlight.DieTime = CurTime() + 2
        end
    end

    function EFFECT:Think() return false end
    function EFFECT:Render() end
    effects.Register(EFFECT, "GilbNukeExplosion")
end

weapons.Register(SWEP, SWEP_NAME)
]])

Player(11):ChatPrint("Tactical Nuke SWEP registered! Find it in 'Claude Weapons'. Watch out for the blast!")

Player(11):ChatPrint("feedback")
