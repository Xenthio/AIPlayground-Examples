-- SHARED — networked RAM corruption. Server picks slot+seed+mode, broadcasts to all clients.
-- All players see identical corruption simultaneously.
-- Run again to stop.
RunSharedLua([==[

local NET_MSG      = "TexCorruptor_Hit"
local NET_MSG_STOP = "TexCorruptor_Stop"

------------------------------------------------------------------------
if SERVER then

    if TexCorruptorServer then
        TexCorruptorServer = false
        util.AddNetworkString(NET_MSG_STOP)
        net.Start(NET_MSG_STOP) net.Broadcast()
        print("[TexCorruptor] Server stopped.")
        return
    end
    TexCorruptorServer = true

    util.AddNetworkString(NET_MSG)
    util.AddNetworkString(NET_MSG_STOP)

    local TICK_MIN = 0.5
    local TICK_MAX = 1.5

    local function serverTick()
        if not TexCorruptorServer then return end
        local seed     = math.random(0, 2147483647)
        local slotIdx  = math.random(1, 9999)  -- clients clamp to their slot count
        local mode     = math.random(1, 6)

        net.Start(NET_MSG)
            net.WriteUInt(seed,    32)
            net.WriteUInt(slotIdx, 16)
            net.WriteUInt(mode,    4)
        net.Broadcast()

        timer.Simple(math.random()*(TICK_MAX-TICK_MIN)+TICK_MIN, serverTick)
    end

    timer.Simple(0.5, serverTick)
    print("[TexCorruptor] Server broadcasting corruption events.")
    return
end

------------------------------------------------------------------------
-- CLIENT

if TexCorruptor then
    TexCorruptor.Stop()
    TexCorruptor = nil
    print("[TexCorruptor] Stopped.")
    return
end

include("gilbutils/vtf.lua")

print("[TexCorruptor] Scanning textures...")
TexCorruptor = {}

local RT_SIZE = 512

------------------------------------------------------------------------
local function collectFromMat(mat, slots, seen)
    if not mat or mat:IsError() then return end
    local kv = mat:GetKeyValues()
    for key, _ in pairs(kv) do
        if key:sub(1,1) == "$" then
            local ok, tex = pcall(function() return mat:GetTexture(key) end)
            if ok and tex and not tex:IsError() then
                local tname = tex:GetName()
                local slotKey = tname.."|"..key
                if not seen[slotKey] then
                    seen[slotKey] = true
                    local vtf = file.Read("materials/"..tname..".vtf","GAME")
                    if vtf then
                        local info = GilbVTF.Parse(vtf)
                        if info then
                            table.insert(slots, { mat=mat, key=key, origTex=tex, info=info, tname=tname })
                        end
                    end
                end
            end
        end
    end
end

local seen, slots = {}, {}
local world = Entity(0)
if world and world.GetMaterials then
    for _, name in ipairs(world:GetMaterials()) do collectFromMat(Material(name), slots, seen) end
end
for _, ent in ipairs(ents.GetAll()) do
    local mats = ent:GetMaterials()
    if mats then for _, name in ipairs(mats) do
        if name ~= "" then collectFromMat(Material(name), slots, seen) end
    end end
    local ov = ent:GetMaterial()
    if ov and ov ~= "" then collectFromMat(Material(ov), slots, seen) end
end

if #slots == 0 then
    print("[TexCorruptor] No DXT materials.") TexCorruptor=nil return
end

local rtCache = {}
for _, s in ipairs(slots) do
    local rtKey = (s.tname..s.key):gsub("[^%w]","_"):sub(-32)
    if not rtCache[rtKey] then
        local rt = GetRenderTargetEx("TC_"..rtKey, RT_SIZE, RT_SIZE,
            RT_SIZE_NO_CHANGE, MATERIAL_RT_DEPTH_NONE,
            0x100, CREATERENDERTARGETFLAGS_HDR, IMAGE_FORMAT_RGBA8888)
        rtCache[rtKey] = rt
    end
    s.rt = rtCache[rtKey]
end

-- Sort slots so all clients have identical order regardless of collection sequence
table.sort(slots, function(a, b)
    local ka = a.tname .. "|" .. a.key
    local kb = b.tname .. "|" .. b.key
    return ka < kb
end)

print(string.format("[TexCorruptor] %d texture slots ready.", #slots))

------------------------------------------------------------------------
local BLOCKS_PER_FRAME = 64
local drawQueue = {}

-- Receive stop from server
net.Receive(NET_MSG_STOP, function()
    if TexCorruptor then
        TexCorruptor.Stop()
        TexCorruptor = nil
        print("[TexCorruptor] Stopped by server.")
    end
end)

-- Receive corruption event from server
net.Receive(NET_MSG, function()
    local seed    = net.ReadUInt(32)
    local slotIdx = net.ReadUInt(16)
    local mode    = net.ReadUInt(4)

    -- Use same seed so all clients pick identical random values for this event
    math.randomseed(seed)
    local s = slots[(slotIdx - 1) % #slots + 1]
    local info = s.info

    -- Corruption uses seeded random (inside RamCorrupt) so all clients corrupt identically
    info.mipData = GilbVTF.RamCorrupt(info.mipData, info.vtf, mode)
    print(string.format("[TexCorruptor] hit %s %s (%dx%d) mode=%d seed=%d",
        s.key, s.tname, info.width, info.height, mode, seed))

    local bw = math.max(1, math.ceil(info.width  / 4))
    local bh = math.max(1, math.ceil(info.height / 4))
    table.insert(drawQueue, {
        s       = s,
        mipData = info.mipData,
        isDXT5  = info.isDXT5,
        bs      = info.isDXT5 and 16 or 8,
        bw      = bw, bh    = bh,
        width   = info.width, height = info.height,
        block   = 0,
        total   = bw * bh,
        sx      = RT_SIZE / info.width,
        sy      = RT_SIZE / info.height,
    })
end)

hook.Add("PostRender", "TexCorruptor_Draw", function()
    if #drawQueue == 0 then return end
    local job = drawQueue[1]
    local s   = job.s

    render.PushRenderTarget(s.rt)
    if job.block == 0 then render.Clear(0,0,0,255,true,false) end
    cam.Start2D()

    local endBlock = math.min(job.block + BLOCKS_PER_FRAME - 1, job.total - 1)
    for bi = job.block, endBlock do
        local bx  = bi % job.bw
        local by  = math.floor(bi / job.bw)
        local off = bi * job.bs
        local blk = job.mipData:sub(off+1, off+job.bs)
        if #blk < job.bs then blk = blk..string.rep("\0", job.bs-#blk) end
        local px = GilbVTF.DecodeBlock(blk, job.isDXT5)
        local pw = math.max(1, math.ceil(job.sx))
        local ph = math.max(1, math.ceil(job.sy))
        for py=0,3 do for px2=0,3 do
            local p = px[py*4+px2+1]
            if p then
                surface.SetDrawColor(p[1],p[2],p[3],255)
                surface.DrawRect(
                    math.floor((bx*4+px2)*job.sx),
                    math.floor((by*4+py )*job.sy),
                    pw, ph)
            end
        end end
    end

    cam.End2D()
    render.PopRenderTarget()

    job.block = endBlock + 1
    if job.block >= job.total then
        s.mat:SetTexture(s.key, s.rt)
        table.remove(drawQueue, 1)
    end
end)

------------------------------------------------------------------------
function TexCorruptor.Stop()
    hook.Remove("PostRender","TexCorruptor_Draw")
    for _, s in ipairs(slots) do
        s.mat:SetTexture(s.key, s.origTex)
    end
end

]==])
