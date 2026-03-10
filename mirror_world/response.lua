local hookID = "MirrorWorld"

if SERVER then
    util.AddNetworkString("MirrorWorld_State")
    net.Start("MirrorWorld_State")
    net.WriteBool(true)
    net.Broadcast()
end

RunOnClient([=[
    local hook_name = "MirrorWorld"

    local function RemoveFlip(ent)
        if not IsValid(ent) then return end
        if ent._MirrorFlipID then
            ent:RemoveCallback("BuildBonePositions", ent._MirrorFlipID)
            ent._MirrorFlipID = nil
        end
    end

    local function SetupFlip(ent)
        if not IsValid(ent) or ent._MirrorFlipID then return end
        ent._MirrorFlipID = ent:AddCallback("BuildBonePositions", function(self, count)
            local eyePos = EyePos()
            local eyeAng = EyeAngles()
            local camMat = Matrix()
            camMat:SetTranslation(eyePos)
            camMat:SetAngles(eyeAng)
            local viewMat = camMat:GetInverse()
            local scaleMat = Matrix()
            scaleMat:Scale(Vector(1, -1, 1))
            local transform = camMat * scaleMat * viewMat
            for i = 0, count - 1 do
                local boneMat = self:GetBoneMatrix(i)
                if boneMat then self:SetBoneMatrix(i, transform * boneMat) end
            end
        end)
    end

    local function Cleanup()
        local ply = LocalPlayer()
        if IsValid(ply) then
            RemoveFlip(ply:GetViewModel())
            RemoveFlip(ply:GetHands())
        end
        hook.Remove("CreateMove",           hook_name)
        hook.Remove("InputMouseApply",      hook_name)
        hook.Remove("PostDrawEffects",      hook_name)
        hook.Remove("PreDrawViewModel",     hook_name)
        hook.Remove("PostDrawViewModel",    hook_name)
        hook.Remove("PreDrawPlayerHands",   hook_name)
        hook.Remove("PostDrawPlayerHands",  hook_name)
        hook.Remove("FireAnimationEvent",   hook_name)
        hook.Remove("DrawPhysgunBeam",      hook_name)
    end

    local function Activate()
        Cleanup()

        -- Flip movement controls
        hook.Add("CreateMove", hook_name, function(cmd)
            cmd:SetSideMove(-cmd:GetSideMove())
            local buttons = cmd:GetButtons()
            local left  = bit.band(buttons, IN_MOVELEFT)  == IN_MOVELEFT
            local right = bit.band(buttons, IN_MOVERIGHT) == IN_MOVERIGHT
            if left and not right then
                buttons = bit.band(buttons, bit.bnot(IN_MOVELEFT))
                buttons = bit.bor(buttons, IN_MOVERIGHT)
            elseif right and not left then
                buttons = bit.band(buttons, bit.bnot(IN_MOVERIGHT))
                buttons = bit.bor(buttons, IN_MOVELEFT)
            end
            cmd:SetButtons(buttons)
        end)

        -- Flip mouse X
        hook.Add("InputMouseApply", hook_name, function(cmd, x, y, ang)
            local view = cmd:GetViewAngles()
            local pitch = GetConVar("m_pitch"):GetFloat()
            local yaw   = GetConVar("m_yaw"):GetFloat()
            view.y = view.y + (x * yaw)
            view.p = math.Clamp(view.p + (y * pitch), -89, 89)
            cmd:SetViewAngles(view)
            return true
        end)

        -- Flip screen horizontally
        hook.Add("PostDrawEffects", hook_name, function()
            local w, h = ScrW(), ScrH()
            render.CopyRenderTargetToTexture(render.GetScreenEffectTexture())
            render.DrawTextureToScreenRect(render.GetScreenEffectTexture(), w, 0, -w, h)
        end)

        -- Flip viewmodel bones
        hook.Add("PreDrawViewModel", hook_name, function(vm, ply, weapon)
            SetupFlip(vm)
            vm:InvalidateBoneCache(); vm:SetupBones()
            local hands = ply:GetHands()
            if IsValid(hands) then
                if hands:GetParent() ~= vm then SetupFlip(hands)
                else RemoveFlip(hands); hands:InvalidateBoneCache(); hands:SetupBones() end
            end
            render.CullMode(MATERIAL_CULLMODE_CW)
        end)
        hook.Add("PostDrawViewModel",   hook_name, function() render.CullMode(MATERIAL_CULLMODE_CCW) end)
        hook.Add("PreDrawPlayerHands",  hook_name, function() render.CullMode(MATERIAL_CULLMODE_CW) end)
        hook.Add("PostDrawPlayerHands", hook_name, function() render.CullMode(MATERIAL_CULLMODE_CCW) end)

        -- Keep viewmodel bones flipped during physgun beam
        hook.Add("DrawPhysgunBeam", hook_name, function(ply)
            if ply == LocalPlayer() then
                local vm = ply:GetViewModel()
                if IsValid(vm) then vm:InvalidateBoneCache(); vm:SetupBones() end
            end
        end)

        -- Fix shell eject / muzzle flash attachment positions
        hook.Add("FireAnimationEvent", hook_name, function(pos, ang, event, options, wep)
            if event ~= 20 and event ~= 21 and event ~= 6001 then return end
            if not IsValid(wep) then return end
            local ply = wep:GetOwner()
            if not (IsValid(ply) and ply == LocalPlayer()) then return end
            local vm = ply:GetViewModel()
            if not IsValid(vm) then return end
            SetupFlip(vm); vm:InvalidateBoneCache(); vm:SetupBones()
            local attId = (event == 6001) and 1 or 2
            local att = vm:GetAttachment(attId)
            if not att then return end
            local data = EffectData()
            data:SetOrigin(att.Pos); data:SetAngles(att.Ang)
            data:SetEntity(wep); data:SetAttachment(attId); data:SetScale(1)
            util.Effect(event == 6001 and "MuzzleFlash" or "ShellEject", data)
            return true
        end)
    end

    net.Receive("MirrorWorld_State", function()
        if net.ReadBool() then Activate() else Cleanup() end
    end)
]=])
