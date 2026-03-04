-- REALM: SERVER
-- DESCRIPTION: 3-bot deathmatch script. Uses bitwise operations for buttons to fix 'AddButtons' error.
-- CLEANUP: Kick the bots manually or via 'bot' command. Hooks for "BotDeathmatchLogic" and "BotRespawnDM" will remain until map change or manual removal.

local ply = Player(17)
local tr = ply:GetEyeTrace()
local spawnPos = tr.HitPos + Vector(0, 0, 10)

local weapons = {"weapon_ar2", "weapon_smg1", "weapon_shotgun"}
local botModels = {
    "models/player/combine_soldier.mdl",
    "models/player/combine_soldier_prisonguard.mdl",
    "models/player/combine_super_soldier.mdl"
}

local botIndices = {}

for i = 1, 3 do
    local bot = player.CreateNextBot("Gladiator_" .. i)
    if IsValid(bot) then
        local idx = bot:EntIndex()
        table.insert(botIndices, idx)
        
        timer.Simple(0.5, function()
            if not IsValid(bot) then return end
            bot:SetModel(botModels[i])
            bot:Give(weapons[i])
            bot:SelectWeapon(weapons[i])
            bot:SetPos(spawnPos + Vector(math.random(-150, 150), math.random(-150, 150), 10))
            bot:SetArmor(100)
        end)
    end
end

RunSharedLua([[
    local botIndices = {]] .. table.concat(botIndices, ",") .. [[}
    local botLookup = {}
    for _, idx in ipairs(botIndices) do botLookup[idx] = true end

    hook.Add("StartCommand", "BotDeathmatchLogic", function(ply, cmd)
        if not botLookup[ply:EntIndex()] then return end
        if not ply:Alive() then return end

        cmd:ClearMovement()
        cmd:ClearButtons()
        local buttons = 0

        local myPos = ply:GetShootPos()
        local target = nil
        local closestDistSqr = 3000 * 3000

        for _, ent in ipairs(player.GetAll()) do
            if ent == ply or not ent:Alive() or ent:GetObserverMode() ~= OBS_MODE_NONE then continue end
            
            local dSqr = myPos:DistToSqr(ent:GetPos())
            if dSqr < closestDistSqr then
                closestDistSqr = dSqr
                target = ent
            end
        end

        if not IsValid(target) then 
            cmd:SetForwardMove(ply:GetWalkSpeed() * 0.4)
            local ang = ply:GetAngles()
            ang.y = ang.y + math.sin(CurTime()) * 0.5
            cmd:SetViewAngles(ang)
            return 
        end

        local enemyPos = target:GetShootPos()
        local targetAng = (enemyPos - myPos):Angle()
        
        -- Recoil simulation
        targetAng.p = targetAng.p + math.sin(CurTime() * 12) * 0.4
        targetAng.y = targetAng.y + math.cos(CurTime() * 12) * 0.4

        local smoothAng = LerpAngle(0.2, ply:EyeAngles(), targetAng)
        cmd:SetViewAngles(smoothAng)
        ply:SetEyeAngles(smoothAng)

        local dist = math.sqrt(closestDistSqr)
        local activeWep = ply:GetActiveWeapon()
        local isShotgun = IsValid(activeWep) and activeWep:GetClass() == "weapon_shotgun"

        if isShotgun then
            if dist > 100 then
                cmd:SetForwardMove(ply:GetRunSpeed())
                buttons = bit.bor(buttons, IN_SPEED)
            end
        else
            if dist > 500 then
                cmd:SetForwardMove(ply:GetWalkSpeed())
            elseif dist < 250 then
                cmd:SetForwardMove(-ply:GetWalkSpeed())
            end
            cmd:SetSideMove(math.sin(CurTime() * 3) * ply:GetWalkSpeed())
        end

        local tr = util.TraceLine({
            start = myPos,
            endpos = enemyPos,
            filter = ply
        })

        if tr.Entity == target then
            buttons = bit.bor(buttons, IN_ATTACK)
            if dist > 600 or ply:Health() < 40 then
                buttons = bit.bor(buttons, IN_DUCK)
            end
        end

        if IsValid(activeWep) and activeWep:Clip1() == 0 then
            buttons = bit.bor(buttons, IN_RELOAD)
        end

        cmd:SetButtons(buttons)
    end)

    if SERVER then
        hook.Add("PostPlayerDeath", "BotRespawnDM", function(ply)
            if botLookup[ply:EntIndex()] then
                timer.Simple(3, function()
                    if IsValid(ply) and not ply:Alive() then
                        ply:Spawn()
                    end
                end)
            end
        end)
    end
]])

Player({{ID}}):ChatPrint("Fixed Deathmatch Logic: 3 Bots Active.")