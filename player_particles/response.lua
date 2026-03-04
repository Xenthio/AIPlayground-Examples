RunClientLua([[
local ply = Player({{ID}})
local pos = ply:GetPos() + Vector(0, 0, 50)
local emitter = ParticleEmitter(pos)

for i = 1, 100 do
    local part = emitter:Add("effects/spark", pos)
    if part and emitter:IsValid() then
        part:SetDieTime(1.5)
        part:SetStartAlpha(255)
        part:SetEndAlpha(0)
        part:SetStartSize(5)
        part:SetEndSize(0)
        part:SetGravity(Vector(0, 0, -200))
        part:SetVelocity(VectorRand() * 100)
    end
end

emitter:Finish()
]])

Player({{ID}}):ChatPrint("Particles shooting out of you!")