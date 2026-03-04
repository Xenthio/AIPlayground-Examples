local bot = player.CreateNextBot("Gilber")
local botIdx = bot:EntIndex()

RunSharedLua([[
    local botIdx = ]] .. botIdx .. [[

    hook.Add("StartCommand", "BotFollowNearby_" .. botIdx, function(ply, cmd)
        if ply:EntIndex() ~= botIdx then return end
        if not ply:Alive() then return end

        cmd:ClearMovement()
        cmd:ClearButtons()

        local closest = nil
        local closestDist = math.huge

        for _, pl in ipairs(player.GetAll()) do
            if pl == ply or pl:IsBot() or not pl:Alive() then continue end
            local dist = ply:GetPos():DistToSqr(pl:GetPos())
            if dist < closestDist then
                closestDist = dist
                closest = pl
            end
        end

        if not IsValid(closest) then return end

        local aimDir = (closest:GetShootPos() - ply:GetShootPos()):GetNormalized():Angle()
        cmd:SetViewAngles(aimDir)
        ply:SetEyeAngles(aimDir)

        if closestDist > 100 * 100 then
            cmd:SetForwardMove(ply:GetWalkSpeed())
        end

        if closestDist > 500 * 500 then
            cmd:SetButtons(IN_SPEED)
            cmd:SetForwardMove(ply:GetRunSpeed())
        end
    end)
]])

Player({{ID}}):ChatPrint("Follower bot spawned! It will follow the nearest player around.")