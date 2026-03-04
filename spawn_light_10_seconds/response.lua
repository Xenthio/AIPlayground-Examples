local ply = Player({{ID}})
local tr = ply:GetEyeTrace()

local light = ents.Create("light_dynamic")
light:SetPos(tr.HitPos + Vector(0, 0, 20))
light:SetKeyValue("brightness", "5")
light:SetKeyValue("distance", "300")
light:SetKeyValue("color", "255 255 200")
light:Spawn()
light:Activate()

SafeRemoveEntityDelayed(light, 10)

ply:ChatPrint("Spawned a light for 10 seconds!")