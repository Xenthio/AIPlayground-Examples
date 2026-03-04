RunSharedLua([[
ENT = {}
ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Auto Turret"
ENT.Author = "Gilb"
ENT.Category = "Claude Entities"
ENT.Spawnable = true

if SERVER then
    function ENT:Initialize()
        self:SetModel("models/props_lab/lab_magnifyingglass.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end
        self.NextShot = 0
    end

    function ENT:Think()
        if CurTime() < self.NextShot then return end

        local target = nil
        local closest = 1000

        for _, ent in ipairs(ents.FindInSphere(self:GetPos(), 1000)) do
            if ent:IsNPC() and ent:Health() > 0 then
                local dist = self:GetPos():Distance(ent:GetPos())
                if dist < closest then
                    closest = dist
                    target = ent
                end
            end
        end

        if IsValid(target) then
            local bullet = {
                Num = 1,
                Src = self:GetPos() + Vector(0, 0, 10),
                Dir = (target:GetPos() + Vector(0, 0, 40) - self:GetPos()):GetNormalized(),
                Spread = Vector(0.01, 0.01, 0),
                Tracer = 1,
                Force = 5,
                Damage = 10,
            }
            self:FireBullets(bullet)
            self:EmitSound("Weapon_AR2.Single")
            self.NextShot = CurTime() + 0.3
        end

        self:NextThink(CurTime() + 0.1)
        return true
    end
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end
end

scripted_ents.Register(ENT, "gilb_auto_turret")
]])

Player({{ID}}):ChatPrint("Auto Turret SENT registered! Find it in your spawn menu under Claude Entities.")