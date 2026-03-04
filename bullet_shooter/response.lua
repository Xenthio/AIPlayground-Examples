RunSharedLua([[
SWEP = {Primary = {}, Secondary = {}}
SWEP.Base = "weapon_base"
SWEP.PrintName = "Custom SMG"
SWEP.Author = "Gilb"
SWEP.Category = "Claude Weapons"
SWEP.Spawnable = true
SWEP.Slot = 2
SWEP.SlotPos = 1
SWEP.HoldType = "smg"
SWEP.ViewModel = "models/weapons/c_smg1.mdl"
SWEP.WorldModel = "models/weapons/w_smg1.mdl"
SWEP.Primary = { ClipSize = 30, DefaultClip = 120, Automatic = true, Ammo = "SMG1" }
SWEP.Secondary = { ClipSize = -1, DefaultClip = -1, Automatic = false, Ammo = "none" }

function SWEP:Initialize()
    self:SetWeaponHoldType(self.HoldType)
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end
    self:SetNextPrimaryFire(CurTime() + 0.1)
    self:TakePrimaryAmmo(1)
    self:EmitSound("Weapon_SMG1.Single")

    local owner = self:GetOwner()
    local bullet = {
        Num = 1,
        Src = owner:GetShootPos(),
        Dir = owner:GetAimVector(),
        Spread = Vector(0.02, 0.02, 0),
        Tracer = 3,
        Force = 5,
        Damage = 15,
    }
    owner:FireBullets(bullet)

    if SERVER then
        owner:ViewPunch(Angle(-1, 0, 0))
    end
end

function SWEP:SecondaryAttack() end

weapons.Register(SWEP, "custom_smg")
]])

Player({{ID}}):ChatPrint("Custom SMG registered! Find it in your spawn menu under Claude Weapons.")