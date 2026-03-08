-- CLIENT — corrupt ALL textures: world, models, normal maps, blend textures, everything.
-- Every 0.5-1.5s a random texture slot gets hit with RAM corruption.
-- Run again to stop + restore.
RunClientLua([==[
if TexCorruptor then
    TexCorruptor.Stop()
    TexCorruptor = nil
    print("[TexCorruptor] Stopped.")
    return
end

include("gilbutils/vtf.lua")

print("[TexCorruptor] Scanning all textures...")
TexCorruptor = {}

local RT_SIZE  = 512
local TICK_MIN = 0.5
local TICK_MAX = 1.5

------------------------------------------------------------------------
-- Collect all unique DXT texture slots from all materials
-- Returns list of { mat, key, origTex, rt, info }
local function collectFromMat(mat, slots, seen)
    if not mat or mat:IsError() then return end
    -- Try every key in the material's keyvalue table
    local kv = mat:GetKeyValues()
    for key, _ in pairs(kv) do
        if key:sub(1,1) == "$" then
            local ok, tex = pcall(function() return mat:GetTexture(key) end)
            if ok and tex and not tex:IsError() then
                local tname = tex:GetName()
                local slotKey = tname .. "|" .. key
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

local seen  = {}
local slots = {}

-- World materials
local world = Entity(0)
if world and world.GetMaterials then
    for _, name in ipairs(world:GetMaterials()) do
        collectFromMat(Material(name), slots, seen)
    end
end

-- All entity materials
for _, ent in ipairs(ents.GetAll()) do
    -- Sub-materials (model surfaces)
    local mats = ent:GetMaterials()
    if mats then
        for _, name in ipairs(mats) do
            if name ~= "" then collectFromMat(Material(name), slots, seen) end
        end
    end
    -- Material override
    local ov = ent:GetMaterial()
    if ov and ov ~= "" then collectFromMat(Material(ov), slots, seen) end
end

if #slots == 0 then
    print("[TexCorruptor] Nothing found.") TexCorruptor=nil return
end

-- Allocate RTs (reuse by tname+key)
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

print(string.format("[TexCorruptor] %d texture slots ready. Chaos begins...", #slots))

------------------------------------------------------------------------
local BLOCKS_PER_FRAME = 64  -- DXT blocks decoded+drawn per frame; tune for smoothness
local drawQueue = {}

local function corruptTick()
    local s    = slots[math.random(1, #slots)]
    local info = s.info
    info.mipData = GilbVTF.RamCorrupt(info.mipData, info.vtf)
    print(string.format("[TexCorruptor] hit %s %s (%dx%d)", s.key, s.tname, info.width, info.height))
    -- Store only raw mip string — no pixel table in memory
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
    timer.Simple(math.random()*(TICK_MAX-TICK_MIN)+TICK_MIN, corruptTick)
end

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

timer.Simple(0.5, corruptTick)

function TexCorruptor.Stop()
    hook.Remove("PostRender","TexCorruptor_Draw")
    timer.Remove("TexCorruptor_Tick")
    for _, s in ipairs(slots) do
        s.mat:SetTexture(s.key, s.origTex)
    end
end
]==])
