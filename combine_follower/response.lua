local ply = Player({{ID}})
local tr = ply:GetEyeTrace()

local npc = ents.Create("npc_combine_s")
npc:SetModel("models/combine_soldier.mdl")
npc:SetPos(tr.HitPos + Vector(0, 0, 10))
npc:SetKeyValue("spawnflags", "256")
npc:Spawn()
npc:Activate()
npc:SetSchedule(SCHED_FORCED_GO)
npc:SetTarget(ply)

timer.Create("NPCFollow_" .. npc:EntIndex(), 2, 0, function()
    if not IsValid(npc) or not IsValid(ply) then
        timer.Remove("NPCFollow_" .. npc:EntIndex())
        return
    end
    npc:SetLastPosition(ply:GetPos() + ply:GetForward() * 100)
    npc:SetSchedule(SCHED_FORCED_GO)
end)

ply:ChatPrint("Spawned a combine soldier that follows you!")