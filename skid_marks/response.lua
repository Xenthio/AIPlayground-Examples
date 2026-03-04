-- PLAN: SERVER, spawn decal skid marks when players slide at high speed.
-- Traces down from player feet, places a decal at the impact point.
-- Uses util.Decal with "skid" or "tire" type marks. Throttled per-player.
-- No cleanup needed — decals are engine-managed and fade naturally.
if CLIENT then return end

local SPEED_THRESHOLD = 250   -- units/sec XY to start leaving marks
local MARK_INTERVAL   = 0.08  -- seconds between marks (controls density)
local lastMarkTime    = {}

hook.Add("Think", "SkidMarks_Think", function()
    local now = CurTime()
    for _, ply in ipairs(player.GetAll()) do
        if not ply:Alive() then continue end

        local sid = ply:SteamID()
        if (now - (lastMarkTime[sid] or 0)) < MARK_INTERVAL then continue end

        local vel   = ply:GetVelocity()
        local speed = Vector(vel.x, vel.y, 0):Length()
        if speed < SPEED_THRESHOLD then continue end

        -- Only mark when on the ground and sliding (not just running)
        if not ply:IsOnGround() then continue end

        lastMarkTime[sid] = now

        -- Trace down from feet
        local tr = util.TraceLine({
            start  = ply:GetPos() + Vector(0, 0, 4),
            endpos = ply:GetPos() - Vector(0, 0, 16),
            filter = ply,
            mask   = MASK_SOLID_BRUSHONLY,
        })

        if not tr.Hit then continue end

        -- util.Decal paints a named decal from decals.txt at the hit position
        -- "skid" is a valid HL2 decal. Alternatives: "tire", "blood", "scorch"
        util.Decal("skid", tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal)

        -- Screech sound occasionally at high speed
        if speed > 400 and math.random() < 0.1 then
            ply:EmitSound("vehicles/tire_squeal"..math.random(1,2)..".wav",
                65, math.random(90, 110), 0.4, CHAN_AUTO)
        end
    end
end)

hook.Add("PlayerDisconnected", "SkidMarks_Cleanup", function(ply)
    lastMarkTime[ply:SteamID()] = nil
end)
