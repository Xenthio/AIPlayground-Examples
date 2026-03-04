-- PLAN: CLIENT, leave skid mark decals on the ground when moving fast.
-- Decals are client-side in GMod -- util.Decal is called on the client.
-- Traces down from local player feet when XY speed exceeds threshold.
RunClientLua([==[
local SPEED_THRESHOLD = 250
local MARK_INTERVAL   = 0.08
local lastMark        = 0

hook.Add("Think", "SkidMarks_Think", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    if not ply:IsOnGround() then return end

    local now   = CurTime()
    if now - lastMark < MARK_INTERVAL then return end

    local vel   = ply:GetVelocity()
    local speed = Vector(vel.x, vel.y, 0):Length()
    if speed < SPEED_THRESHOLD then return end

    lastMark = now

    local tr = util.TraceLine({
        start  = ply:GetPos() + Vector(0, 0, 4),
        endpos = ply:GetPos() - Vector(0, 0, 16),
        filter = ply,
        mask   = MASK_SOLID_BRUSHONLY,
    })
    if not tr.Hit then return end

    -- "skid" is a valid HL2 decal name. Alternatives: "tire", "scorch", "blood"
    util.Decal("skid", tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal)

    if speed > 400 and math.random() < 0.1 then
        surface.PlaySound("vehicles/tire_squeal" .. math.random(1, 2) .. ".wav")
    end
end)
]==])

Player({{ID}}):ChatPrint("Skid marks active.")
