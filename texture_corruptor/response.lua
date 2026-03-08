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
local ROWS_PER_FRAME = 1  -- rows of pixels to draw per PostRender; tune for smoothness

-- Queue: list of in-progress draw jobs
local drawQueue = {}

local function corruptTick()
    local s    = slots[math.random(1, #slots)]
    local info = s.info
    info.mipData = GilbVTF.RamCorrupt(info.mipData, info.vtf)
    print(string.format("[TexCorruptor] hit %s %s (%dx%d)", s.key, s.tname, info.width, info.height))
    -- Decode immediately (fast string ops), queue the slow RT draw
    local pixels = GilbVTF.DecodeMip(info.mipData, info.width, info.height, info.isDXT5)
    table.insert(drawQueue, {
        s      = s,
        pixels = pixels,
        row    = 0,  -- next row to draw
        sx     = RT_SIZE / info.width,
        sy     = RT_SIZE / info.height,
        pw     = math.max(1, math.ceil(RT_SIZE / info.width)),
        ph     = math.max(1, math.ceil(RT_SIZE / info.height)),
    })
    timer.Simple(math.random()*(TICK_MAX-TICK_MIN)+TICK_MIN, corruptTick)
end

hook.Add("PostRender", "TexCorruptor_Draw", function()
    if #drawQueue == 0 then return end
    local job = drawQueue[1]
    local s   = job.s
    local info = s.info

    render.PushRenderTarget(s.rt)
    if job.row == 0 then render.Clear(0,0,0,255,true,false) end
    cam.Start2D()

    local endRow = math.min(job.row + ROWS_PER_FRAME - 1, info.height - 1)
    for py = job.row, endRow do
        for px2 = 0, info.width-1 do
            local p = job.pixels[py*info.width+px2+1]
            if p then
                surface.SetDrawColor(p[1],p[2],p[3],255)
                surface.DrawRect(math.floor(px2*job.sx), math.floor(py*job.sy), job.pw, job.ph)
            end
        end
    end

    cam.End2D()
    render.PopRenderTarget()

    job.row = endRow + 1
    if job.row >= info.height then
        -- Done — apply to material
        s.mat:SetTexture(s.key, s.rt)
        table.remove(drawQueue, 1)
    end
end)

timer.Simple(0.5, corruptTick)

------------------------------------------------------------------------
function TexCorruptor.Stop()
    hook.Remove("PostRender","TexCorruptor_Draw")
    timer.Remove("TexCorruptor_Tick")
    for _, s in ipairs(slots) do
        s.mat:SetTexture(s.key, s.origTex)
    end
end
]==])
