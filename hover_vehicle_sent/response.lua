RunSharedLua([[
ENT = {}
ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Hover Craft"
ENT.Author = "AIPlayground"
ENT.Category = "AI Entities"
ENT.Spawnable = true

if SERVER then
    function ENT:Initialize()
        self:SetModel("models/airboat.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
            phys:SetDamping(5, 10)
            phys:EnableGravity(false)
        end

        local seat = ents.Create("prop_vehicle_prisoner_pod")
        seat:SetModel("models/nova/airboat_seat.mdl")
        seat:SetKeyValue("vehiclescript", "scripts/vehicles/prisoner_pod.txt")
        seat:SetKeyValue("limitview", "0")
        seat:SetPos(self:GetPos() + Vector(0, 0, 30))
        seat:SetAngles(self:GetAngles())
        seat:SetParent(self)
        seat:Spawn()
        seat:Activate()
        self.Seat = seat
        self.WasOccupied = false
        self.ExitTime = -10
    end

    function ENT:Use(activator)
        if not activator:IsPlayer() then return end
        if not IsValid(self.Seat) then return end
        if IsValid(self.Seat:GetDriver()) then return end
        if CurTime() - self.ExitTime < 1.5 then return end -- block re-entry right after exit
        self.Seat:Use(activator, activator, USE_ON, 1)
    end

    function ENT:Think()
        local phys = self:GetPhysicsObject()
        if not IsValid(phys) then return end

        -- Detect exit: driver just left, set ExitTime
        local driver = IsValid(self.Seat) and self.Seat:GetDriver() or nil
        local occupied = IsValid(driver)
        if self.WasOccupied and not occupied then
            self.ExitTime = CurTime()
        end
        self.WasOccupied = occupied

        -- Hover
        local tr = util.TraceLine({ start = self:GetPos(), endpos = self:GetPos() - Vector(0,0,200), filter = { self, self.Seat } })
        local heightError = 80 - tr.Fraction * 200
        phys:ApplyForceCenter(Vector(0, 0, math.Clamp(heightError * 40, -2000, 2000)))

        -- Keep upright
        local ang = self:GetAngles()
        if math.abs(ang.p) > 0.5 or math.abs(ang.r) > 0.5 then
            phys:SetAngles(Angle(0, ang.y, 0))
        end

        local yawVel = 0
        if occupied then
            local fwd = self:GetRight(); fwd.z = 0; fwd:Normalize()

            local thrust = Vector(0,0,0)
            if driver:KeyDown(IN_FORWARD) then thrust = thrust + fwd end
            if driver:KeyDown(IN_BACK)    then thrust = thrust - fwd * 0.6 end
            if driver:KeyDown(IN_JUMP)    then thrust.z = thrust.z + 0.8 end
            phys:ApplyForceCenter(thrust * phys:GetMass() * 25)

            -- Use mouse yaw to steer
            local aimYaw = driver:EyeAngles().y
            local craftYaw = self:GetAngles().y
            local diff = math.AngleDifference(aimYaw, craftYaw)
            yawVel = math.Clamp(diff * 3, -120, 120)
        end

        phys:SetAngleVelocity(Vector(0, yawVel, 0))

        self:NextThink(CurTime())
        return true
    end

    function ENT:OnRemove()
        if IsValid(self.Seat) then self.Seat:Remove() end
    end
end

if CLIENT then
    function ENT:Draw() self:DrawModel() end
end

scripted_ents.Register(ENT, "ai_hover_craft")
]])

local ply = Player({{ID}})
local tr = ply:GetEyeTrace()
local ent = ents.Create("ai_hover_craft")
ent:SetPos(tr.HitPos + Vector(0, 0, 80))
ent:SetAngles(Angle(0, ply:GetAngles().y, 0))
ent:Spawn()
ent:Activate()
ply:ChatPrint("Hover Craft: E to enter, W/S to move, mouse to steer, Space for altitude, E to exit.")
