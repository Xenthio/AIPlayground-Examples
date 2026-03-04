local ply = Player({{ID}})
local tr = ply:GetEyeTrace()

local barrel = ents.Create("prop_physics")
barrel:SetModel("models/props_borealis/bluebarrel001.mdl")
barrel:SetPos(tr.HitPos + Vector(0, 0, 10))
barrel:SetColor(Color(0, 100, 255))
barrel:Spawn()
barrel:Activate()

ply:ChatPrint("Spawned a blue barrel where you're looking!")