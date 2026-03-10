-- texture_corruptor2: VTF-file-based corruption with real mipmaps.
-- Server picks seed+mode+texName. Client corrupts and applies to all mats sharing that texture.
-- Run again to stop + restore.
RunSharedLua([==[

local NET_MSG      = "TexCorruptor2_Hit"
local NET_MSG_STOP = "TexCorruptor2_Stop"
local NET_MSG_MATS = "TexCorruptor2_Mats"

------------------------------------------------------------------------
if SERVER then

    if TexCorruptor2Server then
        TexCorruptor2Server = false
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
local TICK_MAX = 1.0

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
        local seed    = math.random(0, 2147483647)
        -- Mode is picked server-side so all clients corrupt the same way.
        -- GilbData.Corrupt supports modes 1-14 (see gilbutils/data.lua for full list).
        -- To target specific hardware failure aesthetics, use GilbData.RandomModeFor:
        --   GilbData.RandomModeFor("vram")              — VRAM failure (stuck bits, stride glitches, echo)
        --   GilbData.RandomModeFor({"gpu", "bus"})      — GPU subsystem meltdown
        --   GilbData.RandomModeFor({"disk", "ssd"})     — storage failure (sector repeat, block transpose)
        -- Clients can also override locally with: gilbdata_force_mode vram  (or a number 1-14)
        local mode    = math.random(1, 14)
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

include("gilbutils/data.lua")
include("gilbutils/vtf.lua")
include("gilbutils/mat.lua")
include("gilbutils/mdl.lua")
include("gilbutils/bsp.lua")

TexCorruptor2 = {}
TexCorruptor2.tm = tm  -- exposed for debugging

-- GilbMat.NewTexMap() — creates a deduplicated texture→refs map.
-- tm.cache[texName] = { refs=[{mat,key,origTex},...], loaded, ... }
-- tm.list = ordered list of unique texture names for random picking.
-- One entry per unique underlying texture regardless of how many materials share it.
local tm      = GilbMat.NewTexMap()
local vtfData      = {}   -- texName → { dataPath, matPath, info, loaded, applied }

file.CreateDir("texcorrupt2")

local pendingMats  = {}
local pendingFlush = false

local function flushToServer()
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

-- onNewTex is called by GilbMat.RegisterMat() the first time a texture name is discovered.
-- Here we set up our vtfData entry (file paths) and report the name to the server.
local function onNewTex(tname)
    local fname    = tname:gsub("[^%w]","_"):sub(-48)
    local dataPath = "texcorrupt2/" .. fname
    local matPath  = "../data/texcorrupt2/" .. fname
    vtfData[tname] = { dataPath=dataPath, matPath=matPath, loaded=false, applied=false }
    -- Report to server
    pendingMats[tname] = true
    if not pendingFlush then
        pendingFlush = true
        timer.Simple(2, function() pendingFlush = false; flushToServer() end)
    end
end

-- Set up scanner
-- GilbMat.NewScanner() — batched per-frame mat scanner. Processes batchSize mats/frame.
-- :QueueWorld()   — queues all world + entity materials.
-- :QueueEntity()  — queues materials from a single entity.
-- :Queue(name)    — queue a single mat name.
-- :Start()        — begins the Think-hook processing loop.
-- :Stop()         — cancels scanning.
-- onNewTex is forwarded to RegisterMat so we get notified of new textures as they're discovered.
local scanner = GilbMat.NewScanner(tm, onNewTex, function()
    print(string.format("[TexCorruptor2] Scan complete. %d unique textures.", #tm.list))
end)

-- Defer BSP + world scan until after first render so materials are actually loaded in VRAM.
-- The Material() intercept starts immediately to catch anything that loads before then.
GilbMat.StartIntercept(scanner)
GilbMat.StartDecalIntercept(scanner)
GilbMat.StartParticleIntercept(scanner)

hook.Add("PostRender", "TexCorruptor2_FirstFrame", function()
    hook.Remove("PostRender", "TexCorruptor2_FirstFrame")
    -- Now the world has drawn at least once — materials are resident in memory
    scanner:QueueBSP()
    scanner:QueueWorld()
    scanner:QueueSprites()
    scanner:QueueCommon()
    -- Viewmodel
    local vm = IsValid(LocalPlayer()) and LocalPlayer():GetViewModel()
    if IsValid(vm) then scanner:QueueEntity(vm) end
    scanner:Start()
end)

-- Scan newly spawned entities as they arrive so their textures enter the corruption pool.
-- The Material() intercept catches engine-driven loads, but this covers entities that
-- spawn without immediately triggering a Material() call (e.g. off-screen spawns).
hook.Add("OnEntityCreated", "TexCorruptor2_NewEnt", function(ent)
    timer.Simple(0.1, function()
        if IsValid(ent) then
            scanner:QueueEntity(ent)
            scanner:Start()  -- restart Think hook if it finished after initial scan
        end
    end)
end)
-- Expose tm for console debugging: #TexCorruptor2.tm.list, TexCorruptor2.tm.cache["name"]
TexCorruptor2.tm = tm

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
    local tname = net.ReadString()

    local vd = vtfData[tname]
    if not vd then return end  -- haven't seen this texture yet

    -- Lazy VTF load + VMT write on first hit
    if not vd.loaded then
        local vtfBytes = file.Read("materials/" .. tname .. ".vtf", "GAME")
        if not vtfBytes then return end  -- not on disk (UI icon, PNG, etc.)
        local info = GilbVTF.Parse(vtfBytes)
        if not info then return end  -- unsupported VTF format (DXT3, unusual version, etc.)
        file.Write(vd.dataPath .. ".vmt",
            '"UnlitGeneric"\n{\n\t"$basetexture" "' .. vd.matPath .. '"\n}\n')
        vd.info   = info
        vd.loaded = true
        print(string.format("[TexCorruptor2] loaded %s (%dx%d)", tname, info.width, info.height))
    end

    math.randomseed(seed)
    local info    = vd.info
    local offsets = GilbVTF.MipOffsets(info)
    local allMip  = info.allMipData

    -- GilbData.Corrupt(data, allData, mode) — corrupt any binary byte string.
    -- Works on VTF mip data, VVD vertex blocks, MDL headers, WAV audio, anything.
    -- allData is an optional wider pool to bleed bytes from (used by mode 3: DATA BLEED).
    -- mode 1-6 or nil for random: stride repeat, bit flip, data bleed, xor pattern, zero wipe, sprinkle.
    allMip = (GilbData.Corrupt(allMip, info.vtf, mode))
    local numExtra = math.random(2, 3)
    for i = 1, numExtra do
        local m = offsets[math.random(1, #offsets)]
        local slice = allMip:sub(m.offset, m.offset + m.size - 1)
        slice = (GilbData.Corrupt(slice, allMip, math.random(1, 6)))
        allMip = allMip:sub(1, m.offset - 1) .. slice .. allMip:sub(m.offset + m.size)
    end
    info.allMipData = allMip
    info.mipData    = allMip:sub(#allMip - offsets[#offsets].size + 1)

    file.Write(vd.dataPath .. ".vtf", GilbVTF.Rebuild(info, info.allMipData))

    -- Bind once; subsequent writes hotload automatically
    if not vd.applied then
        local newMat = _G._OrigMaterial(vd.matPath)
        if not newMat:IsError() then
            local ok, t = pcall(function() return newMat:GetTexture("$basetexture") end)
            if ok and t and not t:IsError() then
                -- GilbMat.ApplyTex() — sets the new texture on every mat+slot ref sharing this texture name.
    -- This is the key dedup payoff: one corrupted VTF applied to all N materials at once.
    GilbMat.ApplyTex(tm, tname, t)
                vd.applied = true
            end
        end
    end

    local entry = tm.cache[tname]
    print(string.format("[TexCorruptor2] hit %s refs=%d mode=%d", tname, entry and #entry.refs or 0, mode))
end)

------------------------------------------------------------------------
function TexCorruptor2.Stop()
    scanner:Stop()
    hook.Remove("OnEntityCreated", "TexCorruptor2_NewEnt")
    GilbMat.StopIntercept()
    GilbMat.StopDecalIntercept()
    GilbMat.StopParticleIntercept()
    -- GilbMat.RestoreAll() — iterates all refs in the TexMap and restores origTex on each mat+slot.
    GilbMat.RestoreAll(tm)
    print("[TexCorruptor2] Restored all textures.")
end

]==])
