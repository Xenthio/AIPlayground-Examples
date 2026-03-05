-- Lua vehicle: prop chassis driven by physics forces + CreateMove input
-- Realm: Shared

util.AddNetworkString("AIVeh_Input")
util.AddNetworkString("AIVeh_Exit")

if SERVER then
    local drivers = {} -- ply -> { prop, fwd, yaw }

    local function spawnVehicle(ply)
        local prop = ents.Create("prop_physics")
        prop:SetModel("models/props_vehicles/van001.mdl")
        prop:SetPos(ply:GetPos() + ply:GetForward() * 150 + Vector(0, 0, 40))
        prop:SetAngles(Angle(0, ply:EyeAngles().y, 0))
        prop:Spawn()
        prop:GetPhysicsObject():SetDamping(0.3, 0.8)
        drivers[ply] = { prop = prop, fwd = 0, yaw = 0 }
        ply:Freeze(true)
        ply:SetMoveType(MOVETYPE_NOCLIP)
    end

    hook.Add("Think", "AIVeh_Drive", function()
        for ply, v in pairs(drivers) do
            if not IsValid(ply) or not IsValid(v.prop) then drivers[ply] = nil continue end
            local phys = v.prop:GetPhysicsObject()
            if not IsValid(phys) then continue end

            -- Steer
            local av = phys:GetAngleVelocity()
            phys:AddAngleVelocity(Vector(0, 0, -av.z * 0.8 + v.side * -120))

            -- Drive
            local fwdForce = Angle(0, v.yaw, 0):Forward() * v.fwd * 80000
            phys:ApplyCentralForce(fwdForce)

            -- Speed cap
            local vel = phys:GetVelocity()
            if vel:Length() > 700 then phys:SetVelocity(vel:GetNormalized() * 700) end

            -- Seat player on prop
            ply:SetPos(v.prop:GetPos() + v.prop:GetUp() * 55)
            ply:SetAngles(Angle(0, v.prop:GetAngles().y, 0))
        end
    end)

    net.Receive("AIVeh_Input", function(len, ply)
        local v = drivers[ply]
        if not v then return end
        v.fwd  = net.ReadFloat()
        v.side = net.ReadFloat()
        v.yaw  = net.ReadFloat()
    end)

    net.Receive("AIVeh_Exit", function(len, ply)
        local v = drivers[ply]
        if not v then return end
        if IsValid(v.prop) then v.prop:Remove() end
        ply:Freeze(false)
        ply:SetMoveType(MOVETYPE_WALK)
        drivers[ply] = nil
        ply:ChatPrint("Exited vehicle.")
    end)

    spawnVehicle(RequestingPlayer)
    RequestingPlayer:ChatPrint("Vehicle spawned! WASD to drive, E to exit.")
end

if CLIENT then
    hook.Add("CreateMove", "AIVeh_Input", function(cmd)
        if not LocalPlayer():IsFrozen() then return end
        -- Exit on Use
        if cmd:KeyDown(IN_USE) then
            net.Start("AIVeh_Exit") net.SendToServer()
        end
        net.Start("AIVeh_Input")
        net.WriteFloat(cmd:GetForwardMove() / 400)
        net.WriteFloat(cmd:GetSideMove() / 400)
        net.WriteFloat(cmd:GetViewAngles().y)
        net.SendToServer()
        cmd:SetForwardMove(0) cmd:SetSideMove(0)
    end)
end
