-- texture_corruptor2: VTF-file-based corruption with real mipmaps.
-- Server sends seed+mode only. Client picks from deduplicated texture list,
-- corrupts the VTF, and applies it to ALL materials sharing that texture.
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

    local texNames = {}
    local texSeen  = {}
    local function addTex(name)
        if name and name ~= "" and not texSeen[name] then
            texSeen[name] = true
            table.insert(texNames, name)
        end
    end

    net.Receive(NET_MSG_MATS, function(_, ply)
        local count = net.ReadUInt(8)
        for i = 1, count do addTex(net.ReadString()) end
        print(string.format("[TexCorruptor2] +%d textures from %s (total %d)", count, ply:Nick(), #texNames))
    end)

    local function serverTick()
        if not TexCorruptor2Server then return end
        if #texNames == 0 then timer.Simple(1, serverTick) return end
        -- Server picks seed + mode + texture name — everyone corrupts the same texture
        local seed    = math.random(0, 2147483647)
        local mode    = math.random(1, 6)
        local texName = texNames[math.random(1, #texNames)]
        net.Start(NET_MSG)
            net.WriteUInt(seed, 32)
            net.WriteUInt(mode,  4)
            net.WriteString(texName)
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

-- texCache: texName → { info, dataPath, matPath, applied, refs=[{mat,key,origTex},...] }
-- Deduplicated by actual underlying texture name — one VTF per unique texture.
local texCache     = {}
local texList      = {}
local matSeen      = {}  -- already-registered mat names
local pendingMats  = {}
local pendingFlush = false

file.CreateDir("texcorrupt2")

local texSlots = { "$basetexture", "$basetexture2", "$bumpmap", "$bumpmap2",
                   "$detail", "$blendmodulatetexture", "$blendtexture",
                   "$blendmasktexture", "$normalmap", "$normalmap2" }

-- Try to register all slots for a mat — single Material() call, then iterate slots.
local function flushTexNames()
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
end

local function registerMat(matName)
    if not matName or matName == "" or matName:sub(1,2) == ".." then return end
    if matSeen[matName] then return end
    matSeen[matName] = true
    local mat = _OrigMaterial(matName)  -- use original to avoid re-intercepting
    if not mat or mat:IsError() then return end
    for _, key in ipairs(texSlots) do
        local ok, tex = pcall(function() return mat:GetTexture(key) end)
        if not ok or not tex or tex:IsError() then continue end
        local tname = tex:GetName()
        if not tname or tname == "" then continue end

        if not texCache[tname] then
            local fname    = tname:gsub("[^%w]","_"):sub(-48)
            local dataPath = "texcorrupt2/"..fname
            local matPath  = "../data/texcorrupt2/"..fname
            texCache[tname] = { dataPath=dataPath, matPath=matPath, applied=false, refs={}, loaded=false }
            table.insert(texList, tname)
            pendingMats[tname] = true
            if not pendingFlush then
                pendingFlush = true
                timer.Simple(2, function() pendingFlush = false; flushTexNames() end)
            end
        end

        local entry = texCache[tname]
        local found = false
        for _, r in ipairs(entry.refs) do
            if r.mat == mat and r.key == key then found = true; break end
        end
        if not found then
            table.insert(entry.refs, { mat=mat, key=key, origTex=tex })
        end
    end
end

-- Flush pending texture names to server
-- Stash original as global so Stop() and re-runs can restore it
_G._OrigMaterial = _G._OrigMaterial or Material

Material = function(name, ...)
    local m = _OrigMaterial(name, ...)
    if name and name ~= "" and name:sub(1,2) ~= ".." then
        timer.Simple(0.1, function() registerMat(name) end)
    end
    return m
end

-- Initial scan
-- Collect all mat names first, then process a few per frame to avoid freezing
local scanQueue = {}
local function queueMat(name)
    if name and name ~= "" and name:sub(1,2) ~= ".." and not matSeen[name] then
        scanQueue[#scanQueue+1] = name
    end
end

local world = Entity(0)
if world and world.GetMaterials then
    for _, name in ipairs(world:GetMaterials()) do queueMat(name) end
end
for _, ent in ipairs(ents.GetAll()) do
    if ent.GetMaterials then
        local mats = ent:GetMaterials()
        if mats then for _, name in ipairs(mats) do queueMat(name) end end
    end
end

-- Process scan queue — a few mats per frame so we don't freeze
local BATCH = 32
hook.Add("Think", "TexCorruptor2_InitScan", function()
    if #scanQueue == 0 then
        hook.Remove("Think", "TexCorruptor2_InitScan")
        print(string.format("[TexCorruptor2] Initial scan complete. %d unique textures.", #texList))
        return
    end
    for i = 1, math.min(BATCH, #scanQueue) do
        registerMat(table.remove(scanQueue, 1))
    end
end)

-- Viewmodel scan after spawn
timer.Simple(1, function()
    if not IsValid(LocalPlayer()) then return end
    local vm = LocalPlayer():GetViewModel()
    if IsValid(vm) then
        local mats = vm:GetMaterials() or {}
        for _, name in ipairs(mats) do queueMat(name) end
    end
end)

net.Receive(NET_MSG_STOP, function()
    if TexCorruptor2 then
        TexCorruptor2.Stop()
        TexCorruptor2 = nil
        print("[TexCorruptor2] Stopped by server.")
    end
end)

net.Receive(NET_MSG, function()
    local seed  = net.ReadUInt(32)
    local mode  = net.ReadUInt(4)
    local tname = net.ReadString()  -- server picked this texture

    if #texList == 0 then return end

    local s = texCache[tname]
    if not s then return end  -- client hasn't seen this texture yet, skip

    -- Lazy load VTF on first hit
    if not s.loaded then
        local vtfBytes = file.Read("materials/"..tname..".vtf", "GAME")
        if not vtfBytes then print("[TexCorruptor2] VTF not found: " .. tname) return end
        local info = GilbVTF.Parse(vtfBytes)
        if not info then print("[TexCorruptor2] VTF parse failed: " .. tname) return end
        -- Write VMT now that we know the texture exists
        file.Write(s.dataPath..".vmt",
            '"UnlitGeneric"\n{\n\t"$basetexture" "'..s.matPath..'"\n}\n')
        s.info   = info
        s.loaded = true
        print(string.format("[TexCorruptor2] loaded %s (%dx%d)", tname, info.width, info.height))
    end

    local info    = s.info
    local offsets = GilbVTF.MipOffsets(info)
    local allMip  = info.allMipData

    -- Big blast across all mip data
    allMip = (GilbVTF.RamCorrupt(allMip, info.vtf, mode))

    -- 2-3 individual mip blasts
    local numExtra = math.random(2, 3)
    for i = 1, numExtra do
        local m = offsets[math.random(1, #offsets)]
        local slice = allMip:sub(m.offset, m.offset + m.size - 1)
        slice = (GilbVTF.RamCorrupt(slice, allMip, math.random(1, 6)))
        allMip = allMip:sub(1, m.offset - 1) .. slice .. allMip:sub(m.offset + m.size)
    end

    info.allMipData = allMip
    info.mipData    = allMip:sub(#allMip - offsets[#offsets].size + 1)

    local newVtf = GilbVTF.Rebuild(info, info.allMipData)
    file.Write(s.dataPath..".vtf", newVtf)

    -- Bind corrupted texture to all materials referencing this texture
    if not s.applied then
        local newMat = _OrigMaterial(s.matPath)
        if not newMat:IsError() then
            local ok, t = pcall(function() return newMat:GetTexture("$basetexture") end)
            if ok and t and not t:IsError() then
                for _, r in ipairs(s.refs) do
                    r.mat:SetTexture(r.key, t)
                end
                s.applied = true
            end
        end
    end

    print(string.format("[TexCorruptor2] hit tex=%s refs=%d mode=%d", tname, #s.refs, mode))
end)

------------------------------------------------------------------------
function TexCorruptor2.Stop()
    Material = _OrigMaterial
    -- Restore all original textures
    for _, entry in pairs(texCache) do
        for _, r in ipairs(entry.refs) do
            r.mat:SetTexture(r.key, r.origTex)
        end
    end
    texCache = {}
    texList  = {}
    print("[TexCorruptor2] Restored all textures.")
end

]==])
