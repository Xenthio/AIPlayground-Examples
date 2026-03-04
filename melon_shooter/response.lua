RunSharedLua([[
SWEP = {Primary = {}, Secondary = {}}
SWEP.Base = "weapon_base"
SWEP.PrintName = "Melon Launcher"
SWEP.Author = "Gilb"
SWEP.Category = "Claude Weapons"
SWEP.Spawnable = true
SWEP.Slot = 3
SWEP.SlotPos = 1
SWEP.ViewModel = "models/weapons/c_pistol.mdl"
SWEP.WorldModel = "models/weapons/w_pistol.mdl"
SWEP.Primary = { ClipSize = -1, DefaultClip = -1, Automatic = false, Ammo = "none" }
SWEP.Secondary = { ClipSize = -1, DefaultClip = -1, Automatic = false, Ammo = "none" }

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 0.5)
    if not SERVER then return end

    local owner = self:GetOwner()
    local melon = ents.Create("prop_physics")
    melon:SetModel("models/props_junk/watermelon01.mdl")
    melon:SetPos(owner:EyePos() + owner:GetAimVector() * 50)
    melon:SetAngles(owner:EyeAngles())
    melon:Spawn()
    melon:Activate()
    melon:GetPhysicsObject():SetVelocity(owner:GetAimVector() * 3000)
    SafeRemoveEntityDelayed(melon, 10)
end

function SWEP:SecondaryAttack() end

weapons.Register(SWEP, "melon_launcher")
]])

Player({{ID}}):ChatPrint("Melon Launcher SWEP registered! Find it in your spawn menu under Claude Weapons.")