-- REALM: SHARED
-- DESCRIPTION: A Rainbow Lightning Bolt gun that fires chaotic, color-shifting electrical arcs.
-- CLEANUP: Effects and beams clean themselves up after a short duration.

RunSharedLua([==[
local SWEP_NAME = "weapon_rainbow_lightning"

local SWEP = {Primary = {}, Secondary = {}} 
SWEP.PrintName = "Prismatic Storm"
SWEP.Author = "Gilb"
SWEP.Category = "Claude Weapons"
SWEP.Spawnable = true
SWEP.Slot = 2
SWEP.SlotPos = 1
SWEP.ViewModel = "models/weapons/c_pistol.mdl"
SWEP.WorldModel = "models/weapons/w_pistol.mdl"
SWEP.UseHands = true
SWEP.HoldType = "pistol"

SWEP.Primary = { 
    ClipSize = -1, 
    DefaultClip = -1, 
    Automatic = true, 
    Ammo = "none", 
    Delay = 0.08 
}
SWEP.Secondary = { ClipSize = -1, DefaultClip = -1, Automatic = false, Ammo = "none" }

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
    
    local owner = self:GetOwner()
    local aimVec = owner:GetAimVector()
    local shootPos = owner:GetShootPos()

    -- Trace to find target
    local tr = util.TraceLine({
        start = shootPos,
        endpos = shootPos + aimVec * 2500,
        filter = owner
    })

    -- Sound and animation
    self:EmitSound("ambient/energy/zap" .. math.random(1, 9) .. ".wav", 75, math.random(150, 200), 0.5)
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    owner:MuzzleFlash()

    -- Rainbow Visuals
    if IsFirstTimePredicted() then
        local vm = owner:GetViewModel()
        local beamStartPos = shootPos
        if IsValid(vm) then
            local obj = vm:LookupAttachment("muzzle")
            if obj > 0 then
                local muzzle = vm:GetAttachment(obj)
                if muzzle then beamStartPos = muzzle.Pos end
            end
        end
        
        local effectData = EffectData()
        effectData:SetOrigin(tr.HitPos)
        effectData:SetStart(beamStartPos)
        effectData:SetEntity(self)
        util.Effect("RainbowLightningBolt", effectData)
    end

    -- Damage and Physics
    if IsFirstTimePredicted() then
        if tr.Hit and IsValid(tr.Entity) and SERVER then
            local dmg = DamageInfo()
            dmg:SetDamage(8)
            dmg:SetDamageType(DMG_SHOCK)
            dmg:SetAttacker(owner)
            dmg:SetInflictor(self)
            dmg:SetDamageForce(aimVec * 8000)
            tr.Entity:TakeDamageInfo(dmg)
        end
        
        -- Rainbow Impact Spark
        local spark = EffectData()
        spark:SetOrigin(tr.HitPos)
        spark:SetNormal(tr.HitNormal)
        util.Effect("RainbowImpact", spark)
    end
end

function SWEP:SecondaryAttack() end

if CLIENT then
    -- CUSTOM LIGHTNING EFFECT
    local EFFECT = {}

    function EFFECT:Init(data)
        self.StartPos = data:GetStart()
        self.EndPos = data:GetOrigin()
        self.DieTime = CurTime() + 0.15
        self.MaxDieTime = 0.15
        self.Segments = 12
        
        -- Generate random offsets for this specific bolt
        self.Points = {}
        for i = 0, self.Segments do
            table.insert(self.Points, VectorRand() * 15)
        end
        
        -- Match hue to time for a global "flow" or use random
        self.Hue = (CurTime() * 200) % 360
    end

    function EFFECT:Think()
        return CurTime() < self.DieTime
    end

    function EFFECT:Render()
        local life = (self.DieTime - CurTime()) / self.MaxDieTime
        local col = HSVToColor(self.Hue, 1, 1)
        col.a = 255 * life

        render.SetMaterial(Material("effects/blueblacklargebeam"))
        
        local lastPos = self.StartPos
        for i = 1, self.Segments do
            local progress = i / self.Segments
            local offset = self.Points[i+1]
            local currentPos = LerpVector(progress, self.StartPos, self.EndPos) + offset
            
            -- Main Beam
            render.DrawBeam(lastPos, currentPos, 12 * life, 0, 1, col)
            -- Inner White Beam
            render.DrawBeam(lastPos, currentPos, 4 * life, 0, 1, Color(255, 255, 255, 255 * life))
            
            lastPos = currentPos
        end
    end
    effects.Register(EFFECT, "RainbowLightningBolt")
    
    -- IMPACT EFFECT
    local IMPACT = {}
    function IMPACT:Init(data)
        local pos = data:GetOrigin()
        local emitter = ParticleEmitter(pos)
        local hue = (CurTime() * 200) % 360
        local col = HSVToColor(hue, 0.8, 1)

        for i = 1, 15 do
            local p = emitter:Add("effects/spark", pos)
            if p then
                p:SetVelocity(VectorRand() * 300 + data:GetNormal() * 200)
                p:SetDieTime(math.Rand(0.2, 0.5))
                p:SetStartAlpha(255)
                p:SetEndAlpha(0)
                p:SetStartSize(math.Rand(2, 5))
                p:SetEndSize(0)
                p:SetColor(col.r, col.g, col.b)
                p:SetGravity(Vector(0,0,-600))
                p:SetCollide(true)
                p:SetBounce(0.5)
            end
        end
        emitter:Finish()
        
        local dl = DynamicLight(0)
        if dl then
            dl.pos = pos
            dl.r, dl.g, dl.b = col.r, col.g, col.b
            dl.brightness = 2
            dl.size = 200
            dl.dieTime = CurTime() + 0.1
        end
    end
    function IMPACT:Think() return false end
    function IMPACT:Render() end
    effects.Register(IMPACT, "RainbowImpact")
end

weapons.Register(SWEP, SWEP_NAME)
]==])

Player({{ID}}):ChatPrint("Prismatic Storm Lightning Gun created! Taste the rainbow.")