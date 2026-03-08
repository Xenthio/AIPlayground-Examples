-- SHARED — networked RAM corruption. Server picks texture+seed+mode, clients handle independently.
-- All players see identical corruption. Run again to stop.
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

    -- Collect world material names server-side to pick from
    local matNames = {}
    local world = Entity(0)  -- world exists server-side too
    if world and world.GetMaterials then
        for _, name in ipairs(world:GetMaterials()) do
            table.insert(matNames, name)
        end
    end
    -- Fallback: just pick from common texture slots
    local texSlots = { "$basetexture", "$basetexture2", "$bumpmap", "$bumpmap2", "$detail" }

    if #matNames == 0 then
        print("[TexCorruptor] Server: no world materials found, stopping.")
        TexCorruptorServer = false return
    end

    local function serverTick()
        if not TexCorruptorServer then return end
        local seed = math.random(0, 2147483647)
        local mode = math.random(1, 6)
        -- Pick a material + slot; client will resolve actual texture name from it
        local matName = matNames[math.random(1, #matNames)] or "missing"
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

print("[TexCorruptor] Ready.")
TexCorruptor = {}

local RT_SIZE = 512

-- Cache of tname+key → slot entry (built lazily on first hit)
local slotCache  = {}
local rtCache    = {}
local BLOCKS_PER_FRAME = 64
local drawQueue  = {}

local function getOrBuildSlot(matName, key)
    local cacheKey = matName.."|"..key
    if slotCache[cacheKey] then return slotCache[cacheKey] end

    local mat = Material(matName)
    if mat:IsError() then return nil end
    local ok, tex = pcall(function() return mat:GetTexture(key) end)
    if not ok or not tex or tex:IsError() then return nil end

    local tname = tex:GetName()
    local vtf   = file.Read("materials/"..tname..".vtf", "GAME")
    if not vtf then return nil end

    local info = GilbVTF.Parse(vtf)
    if not info then return nil end

    local rtKey = (tname..key):gsub("[^%w]","_"):sub(-32)
    if not rtCache[rtKey] then
        local rt = GetRenderTargetEx("TC_"..rtKey, RT_SIZE, RT_SIZE,
            RT_SIZE_NO_CHANGE, MATERIAL_RT_DEPTH_NONE,
            0, CREATERENDERTARGETFLAGS_HDR, IMAGE_FORMAT_RGBA8888)
        rtCache[rtKey] = rt
    end

    local slot = { mat=mat, key=key, origTex=tex, info=info, tname=tname, rt=rtCache[rtKey], rtReady=false }
    slotCache[cacheKey] = slot
    print(string.format("[TexCorruptor] cached %s %s (%dx%d fmt=%d)", key, tname, info.width, info.height, info.fmt))
    return slot
end

net.Receive(NET_MSG_STOP, function()
    if TexCorruptor then
        TexCorruptor.Stop()
        TexCorruptor = nil
        print("[TexCorruptor] Stopped by server.")
    end
end)

net.Receive(NET_MSG, function()
    local seed    = net.ReadUInt(32)
    local mode    = net.ReadUInt(4)
    local matName = net.ReadString()
    local key     = net.ReadString()

    local s = getOrBuildSlot(matName, key)
    if not s then return end  -- texture not present on this client, skip silently

    math.randomseed(seed)
    local info = s.info
    local newMip, byteStart, byteEnd = GilbVTF.RamCorrupt(info.mipData, info.vtf, mode)
    info.mipData = newMip
    print(string.format("[TexCorruptor] hit %s %s mode=%d", key, s.tname, mode))

    local bs      = info.isDXT5 and 16 or 8
    local bw      = math.max(1, math.ceil(info.width  / 4))
    local bh      = math.max(1, math.ceil(info.height / 4))
    -- First hit: full redraw so RT isn't black under corrupted blocks
    local bStart, bEnd
    if not s.rtReady then
        bStart, bEnd = 0, bw*bh - 1
        s.rtReady = true
    else
        bStart = math.floor(byteStart / bs)
        bEnd   = math.min(math.ceil((byteEnd+1) / bs), bw*bh - 1)
    end

    table.insert(drawQueue, {
        s       = s,
        mipData = info.mipData,
        isDXT5  = info.isDXT5,
        bs      = bs,
        bw      = bw, bh     = bh,
        width   = info.width, height = info.height,
        block   = bStart,
        total   = bEnd + 1,
        sx      = RT_SIZE / info.width,
        sy      = RT_SIZE / info.height,
    })
end)

hook.Add("PostRender", "TexCorruptor_Draw", function()
    if #drawQueue == 0 then return end
    local job = drawQueue[1]
    local s   = job.s

    render.PushRenderTarget(s.rt)
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
    for _, s in pairs(slotCache) do
        s.mat:SetTexture(s.key, s.origTex)
    end
end

]==])
