-- HL2 old-engine bunnyhop unfix + new-engine auto-bhop at runtime
-- Ports the exact FinishMove logic from GMod_HL2ified/campaign/player_class.lua:
--   Forward movement: direct velocity boost along facing, NO speed cap
--   Backward/neutral: speed-additive, capped only when moving backwards
-- sv_sticktoground 0 disables the engine landing speed clamp.
-- sv_accelerate 10 HL2's value.
-- sv_friction 4 HL2's value. 
-- sv_gravity 600 HL2's value.

RunSharedLua([[
if SERVER then
    RunConsoleCommand("sv_sticktoground", "0")
    RunConsoleCommand("sv_accelerate", "10")
    RunConsoleCommand("sv_friction", "4")
    RunConsoleCommand("sv_gravity", "600")
end

local function PatchPlayer(ply)
    local inst = ply.m_CurrentPlayerClass
    if not inst or inst._BhopPatched then return end
    inst._BhopPatched = true

    local maxspeed = 200  -- fallback

    -- StartMove: capture maxspeed + auto-bhop via faking fresh IN_JUMP
    inst.StartMove = function(self, move)
        maxspeed = move:GetMaxSpeed()

        if bit.band(move:GetButtons(), IN_JUMP) ~= 0 and self.Player:OnGround() then
            move:SetOldButtons(bit.band(move:GetOldButtons(), bit.bnot(IN_JUMP)))
        end

        -- Set JUMPING for FinishMove (same upvalue trick as sandbox)
        if bit.band(move:GetButtons(), IN_JUMP) ~= 0
        and bit.band(move:GetOldButtons(), IN_JUMP) == 0
        and self.Player:OnGround() then
            JUMPING = true
        end
    end

    -- FinishMove: HL2ified logic — forward boost uncapped, back boost capped only backwards
    inst.FinishMove = function(self, move)
        if not JUMPING then return end
        JUMPING = nil

        local forward = move:GetAngles()
        forward.p = 0
        forward = forward:Forward()

        local forwardMove = move:GetForwardSpeed()
        local sprinting = move:KeyDown(IN_SPEED)
        local crouching = self.Player:Crouching()

        if forwardMove > 0 then
            -- Forward bhop: direct boost, NO cap
            forward.z = 0
            forward:Normalize()
            local scale = (not sprinting and not crouching) and 0.5 or 0.1
            local boost = Vector(forward.x * forwardMove * scale, forward.y * forwardMove * scale, 0)
            move:SetVelocity(move:GetVelocity() + boost)
        else
            -- Backward/neutral bhop: additive, speedcap bug causes backhopping.

            local boostPerc = (not sprinting and not crouching) and 0.5 or 0.1
            local addition = math.abs(forwardMove * boostPerc)
            local capSpeed = maxspeed + maxspeed * boostPerc
            local newSpeed = addition + move:GetVelocity():Length2D()
            local isBackwards = move:GetVelocity():Dot(forward) < 0

            -- This backwards speed cap is actually what CAUSES backhopping! without it, theres no backhopping.
            if isBackwards and newSpeed > capSpeed then
                addition = addition - (newSpeed - capSpeed)
            end
            if forwardMove < 0 then addition = -addition end

            move:SetVelocity(forward * addition + move:GetVelocity())
        end
    end

    print("[BhopUnfix] Patched " .. ply:Nick())
end

hook.Add("PlayerSpawn", "BhopUnfix_Spawn", function(ply)
    timer.Simple(0, function()
        if IsValid(ply) then PatchPlayer(ply) end
    end)
end)

for _, ply in ipairs(player.GetAll()) do
    PatchPlayer(ply)
end

print("[BhopUnfix] Active — forward bhop uncapped, back bhop capped, auto-bhop, sv_sticktoground 0")
]])