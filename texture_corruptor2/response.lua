-- texture_corruptor2: VTF-file-based corruption with real mipmaps.
-- Server picks mat+slot+seed+mode, clients write corrupted VTF to data/ and hotload.
-- Run again to stop + restore.
RunSharedLua([==[

local NET_MSG      = "TexCorruptor2_Hit"
local NET_MSG_STOP = "TexCorruptor2_Stop"
local NET_MSG_MATS = "TexCorruptor2_Mats"

------------------------------------------------------------------------
if SERVER then

    if TexCorruptor2Server then
        TexCorruptor2Server = false
        hook.Remove("OnEntityCreated", "TexCorruptor2_NewEnt")
        util.AddNetworkString(NET_MSG_STOP)
        net.Start(NET_MSG_STOP) net.Broadcast()
        print("[TexCorruptor2] Server stopped.")
        return
    end
    TexCorruptor2Server = true
    util.AddNetworkString(NET_MSG)
    util.AddNetworkString(NET_MSG_STOP)
    util.AddNetworkString(NET_MSG_MATS)

    local TICK_MIN = 0.05
    local TICK_MAX = 0.2

    local matNames = {}
    local matSeen  = {}
    local function addMat(name)
        if name and name ~= "" and not matSeen[name] then
            matSeen[name] = true
            table.insert(matNames, name)
        end
    end

    local world = Entity(0)
    if world and world.GetMaterials then
        for _, name in ipairs(world:GetMaterials()) do addMat(name) end
    end
    for _, ent in ipairs(ents.GetAll()) do
        local mats = ent:GetMaterials()
        if mats then for _, name in ipairs(mats) do addMat(name) end end
        addMat(ent:GetMaterial())
    end

    hook.Add("OnEntityCreated", "TexCorruptor2_NewEnt", function(ent)
        if not TexCorruptor2Server then
            hook.Remove("OnEntityCreated", "TexCorruptor2_NewEnt")
            return
        end
        -- Delay one tick so model/materials are set
        timer.Simple(0, function()
            if not IsValid(ent) then return end
            local mats = ent:GetMaterials()
            if mats then for _, name in ipairs(mats) do addMat(name) end end
            addMat(ent:GetMaterial())
        end)
    end)

    net.Receive(NET_MSG_MATS, function(_, ply)
        local count = net.ReadUInt(8)
        for i = 1, count do addMat(net.ReadString()) end
        print(string.format("[TexCorruptor2] +%d mats from %s (total %d)", count, ply:Nick(), #matNames))
    end)

    local texSlots = { "$basetexture", "$basetexture2", "$bumpmap", "$bumpmap2",
                       "$detail", "$blendmodulatetexture", "$blendtexture",
                       "$blendmasktexture", "$normalmap", "$normalmap2" }

    local function serverTick()
        if not TexCorruptor2Server then return end
        if #matNames == 0 then timer.Simple(1, serverTick) return end
        local seed    = math.random(0, 2147483647)
        local mode    = math.random(1, 6)
        local matName = matNames[math.random(1, #matNames)]
        local slot    = texSlots[math.random(1, #texSlots)]
        net.Start(NET_MSG)
            net.WriteUInt(seed, 32)
            net.WriteUInt(mode,  4)
            net.WriteString(matName)
            net.WriteString(slot)
        net.Broadcast()
        timer.Simple(math.random()*(TICK_MAX-TICK_MIN)+TICK_MIN, serverTick)
    end

    timer.Simple(0.5, serverTick)
    print("[TexCorruptor2] Server running.")
    return
end

------------------------------------------------------------------------
-- CLIENT

if TexCorruptor2 then
    TexCorruptor2.Stop()
    TexCorruptor2 = nil
    print("[TexCorruptor2] Stopped.")
    return
end

include("gilbutils/vtf.lua")

TexCorruptor2 = {}
local slotCache    = {}  -- cacheKey → { mat, key, origTex, info, tname, dataPath, matPath }
local pendingMats  = {}
local pendingFlush = false

file.CreateDir("texcorrupt2")

-- Intercept every Material() call to capture all loaded materials including water, decals, etc.
local _OrigMaterial = _OrigMaterial or Material
Material = function(name, ...)
    if name and name ~= "" and name:sub(1,2) ~= ".." then
        pendingMats[name] = true
        if not pendingFlush then
            pendingFlush = true
            timer.Simple(2, function()
                pendingFlush = false
                local batch = {}
                for n in pairs(pendingMats) do batch[#batch+1] = n; pendingMats[n] = nil end
                if #batch == 0 then return end
                for i = 1, #batch, 60 do
                    net.Start(NET_MSG_MATS)
                        local chunk = math.min(60, #batch - i + 1)
                        net.WriteUInt(chunk, 8)
                        for j = i, i + chunk - 1 do net.WriteString(batch[j]) end
                    net.SendToServer()
                end
            end)
        end
    end
    return _OrigMaterial(name, ...)
end

local function getOrBuildSlot(matName, key)
    local cacheKey = matName.."|"..key
    if slotCache[cacheKey] then return slotCache[cacheKey] end

    local mat = Material(matName)
    if mat:IsError() then return nil end
    local ok, tex = pcall(function() return mat:GetTexture(key) end)
    if not ok or not tex or tex:IsError() then return nil end

    local tname = tex:GetName()
    local vtfBytes = file.Read("materials/"..tname..".vtf", "GAME")
    if not vtfBytes then return nil end

    local info = GilbVTF.Parse(vtfBytes)
    if not info then return nil end

    -- Unique filename per slot
    local fname = (tname..key):gsub("[^%w]","_"):sub(-48)
    local dataPath = "texcorrupt2/"..fname
    local matPath  = "../data/texcorrupt2/"..fname

    -- Write initial VMT (points $basetexture at the VTF via ../data/)
    file.Write(dataPath..".vmt",
        '"UnlitGeneric"\n{\n\t"$basetexture" "'..matPath..'"\n}\n')

    local slot = { mat=mat, key=key, origTex=tex, info=info, tname=tname,
                   dataPath=dataPath, matPath=matPath }
    slotCache[cacheKey] = slot
    print(string.format("[TexCorruptor2] cached %s %s (%dx%d)", key, tname, info.width, info.height))
    return slot
end

-- Send viewmodel mats to server
timer.Simple(1, function()
    local vm = LocalPlayer():GetViewModel()
    if not IsValid(vm) then return end
    local mats = vm:GetMaterials() or {}
    if #mats == 0 then return end
    net.Start(NET_MSG_MATS)
        net.WriteUInt(math.min(#mats, 255), 8)
        for i = 1, math.min(#mats, 255) do net.WriteString(mats[i]) end
    net.SendToServer()
end)

net.Receive(NET_MSG_STOP, function()
    if TexCorruptor2 then
        TexCorruptor2.Stop()
        TexCorruptor2 = nil
        print("[TexCorruptor2] Stopped by server.")
    end
end)

net.Receive(NET_MSG, function()
    local seed    = net.ReadUInt(32)
    local mode    = net.ReadUInt(4)
    local matName = net.ReadString()
    local key     = net.ReadString()

    local s = getOrBuildSlot(matName, key)
    if not s then return end

    math.randomseed(seed)
    local info    = s.info
    local offsets = GilbVTF.MipOffsets(info)
    local allMip  = info.allMipData

    -- One big blast across all mip data combined (simulates bus/DMA corruption hitting the whole texture)
    allMip = (GilbVTF.RamCorrupt(allMip, info.vtf, mode))

    -- Then 2-3 individual mip blasts on randomly chosen mips
    local numExtra = math.random(2, 3)
    for i = 1, numExtra do
        local m = offsets[math.random(1, #offsets)]
        local slice = allMip:sub(m.offset, m.offset + m.size - 1)
        slice = (GilbVTF.RamCorrupt(slice, allMip, math.random(1, 6)))
        allMip = allMip:sub(1, m.offset - 1) .. slice .. allMip:sub(m.offset + m.size)
    end

    info.allMipData = allMip
    info.mipData    = allMip:sub(#allMip - offsets[#offsets].size + 1)

    -- Rebuild and write VTF — hotload picks it up automatically after first apply
    local newVtf = GilbVTF.Rebuild(info, info.allMipData)
    file.Write(s.dataPath..".vtf", newVtf)

    -- Only bind the texture once; subsequent writes hotload automatically
    if not s.applied then
        local newMat = Material(s.matPath)
        if not newMat:IsError() then
            local ok, t = pcall(function() return newMat:GetTexture("$basetexture") end)
            if ok and t and not t:IsError() then
                s.mat:SetTexture(s.key, t)
                s.applied = true
            end
        end
    end

    print(string.format("[TexCorruptor2] hit %s %s mode=%d", key, s.tname, mode))
end)

------------------------------------------------------------------------
function TexCorruptor2.Stop()
    Material = _OrigMaterial
    for _, s in pairs(slotCache) do
        s.mat:SetTexture(s.key, s.origTex)
    end
end

]==])
