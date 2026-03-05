-- Spawns a driveable HL2 jeep in front of the requesting player.
-- Realm: Server

if SERVER then
    local ply = RequestingPlayer
    if not IsValid(ply) then return end

    local pos = ply:GetPos() + ply:GetForward() * 200 + Vector(0, 0, 50)
    local ang = ply:GetAngles()
    ang.p = 0
    ang.r = 0

    local veh = ents.Create("prop_vehicle_jeep")
    veh:SetModel("models/buggy.mdl")
    veh:SetKeyValue("vehiclescript", "scripts/vehicles/jeep_test.txt")
    veh:SetPos(pos)
    veh:SetAngles(ang)
    veh:Spawn()
    veh:Activate()

    -- Let the physics settle
    local phys = veh:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end

    ply:EnterVehicle(veh)

    if IsValid(RequestingPlayer) then
        RequestingPlayer:ChatPrint("Jeep spawned — get in!")
    end
end
