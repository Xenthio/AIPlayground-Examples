local ply = Player({{ID}})
local tr = ply:GetEyeTrace()

local models = {
    "models/props_interiors/furniture_chair01a.mdl",
    "models/props_interiors/furniture_chair03a.mdl",
    "models/props_interiors/furniture_couch01a.mdl",
    "models/props_interiors/furniture_couch02a.mdl",
    "models/props_interiors/furniture_desk01a.mdl",
    "models/props_interiors/furniture_shelf01a.mdl",
}

local prop = ents.Create("prop_physics")
prop:SetModel(models[math.random(#models)])
prop:SetPos(tr.HitPos + Vector(0, 0, 10))
prop:Spawn()
prop:Activate()

ply:ChatPrint("Spawned a random piece of furniture!")