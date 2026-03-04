SWEP hold types control how the player's hands and arms are animated when holding a weapon.
Set via `SWEP.HoldType` in the SWEP table.

## Common Hold Types
- `"pistol"` — one-handed pistol grip (default for most guns)
- `"smg"` — two-handed SMG/rifle hold
- `"ar2"` — two-handed assault rifle (slightly different from smg)
- `"shotgun"` — pump-action shotgun hold
- `"rpg"` — rocket launcher hold (over shoulder)
- `"physgun"` — gravity gun style (outstretched arm)
- `"grenade"` — grenade/thrown object hold
- `"fist"` — bare fist melee
- `"melee"` — one-handed melee (crowbar style)
- `"melee2"` — two-handed melee
- `"slam"` — slam explosive hold
- `"crossbow"` — crossbow hold
- `"passive"` — weapon held loosely at side (knife/passive carry)
- `"knife"` — knife hold (same as passive)
- `"duel"` — dual-wielding hold
- `"camera"` — camera hold

## Viewmodel & Worldmodel
```lua
SWEP.ViewModelFOV   = 54            -- FOV of the viewmodel camera (default 54)
SWEP.ViewModelFlip  = false         -- Mirror the viewmodel horizontally
SWEP.ViewModel      = "models/weapons/c_pistol.mdl"   -- first-person arms+gun
SWEP.WorldModel     = "models/weapons/w_pistol.mdl"   -- third-person world model
```

## Bone Positions (GetBonePosition)
To attach effects to the muzzle, use bone `"ValveBiped.Bip01_R_Hand"` on the worldmodel,
or trace from `owner:GetShootPos()` in the direction of `owner:GetAimVector()`.

## Example SWEP skeleton
```lua
SWEP.HoldType        = "pistol"
SWEP.ViewModel       = "models/weapons/c_pistol.mdl"
SWEP.WorldModel      = "models/weapons/w_pistol.mdl"
SWEP.Primary.Sound   = Sound("Weapon_Pistol.Single")
SWEP.Primary.Damage  = 10
SWEP.Primary.ClipSize = 18
SWEP.Primary.DefaultClip = 18
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo    = "Pistol"

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end
    self:FireBullets({ Num=1, Src=self.Owner:GetShootPos(),
        Dir=self.Owner:GetAimVector(), Spread=Vector(0.02,0.02,0),
        Tracer=0, Force=10, Damage=self.Primary.Damage })
    self:EmitSound(self.Primary.Sound)
    self:TakePrimaryAmmo(1)
    self:SetNextPrimaryFire(CurTime() + 0.15)
end
```
