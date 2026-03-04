-- REALM: CLIENT
-- DESCRIPTION: A 2D Water Surface Tension simulation using a grid of springs. Draws to the screen using HUDPaint.
-- CLEANUP: None (Overwrites its own hook if re-run).

RunClientLua([==[
local gridW = 80
local gridH = 1
local spacing = ScrW() / (gridW - 1)
local centerY = ScrH() * 0.7
local waterNodes = {}

-- Simulation Constants
local damping = 0.98
local tension = 0.02
local spread = 0.25

-- Initialize nodes
for i = 1, gridW do
    waterNodes[i] = {
        targetHeight = centerY,
        height = centerY,
        velocity = 0
    }
end

local function Splash(index, speed)
    if waterNodes[index] then
        waterNodes[index].velocity = speed
    end
end

hook.Add("HUDPaint", "WaterPhysicsSim", function()
    local sw, sh = ScrW(), ScrH()
    
    -- Interaction: Mouse Click or Move
    if input.IsMouseDown(MOUSE_LEFT) then
        local mx = gui.MouseX()
        local idx = math.Round(mx / spacing) + 1
        Splash(idx, 15)
    end

    -- Update Physics (Springs)
    for i = 1, gridW do
        local node = waterNodes[i]
        local x = node.targetHeight - node.height
        node.velocity = node.velocity + tension * x - node.velocity * (1 - damping)
        node.height = node.height + node.velocity
    end

    -- Propagate Waves (L/R)
    local leftDeltas = {}
    local rightDeltas = {}

    for i = 1, gridW do
        if i > 1 then
            leftDeltas[i] = spread * (waterNodes[i].height - waterNodes[i-1].height)
            waterNodes[i-1].velocity = waterNodes[i-1].velocity + leftDeltas[i]
        end
        if i < gridW then
            rightDeltas[i] = spread * (waterNodes[i].height - waterNodes[i+1].height)
            waterNodes[i+1].velocity = waterNodes[i+1].velocity + rightDeltas[i]
        end
    end

    for i = 1, gridW do
        if i > 1 then waterNodes[i-1].height = waterNodes[i-1].height + leftDeltas[i] end
        if i < gridW then waterNodes[i+1].height = waterNodes[i+1].height + rightDeltas[i] end
    end

    -- Draw Water Body
    surface.SetDrawColor(0, 150, 255, 180)
    
    -- Draw vertical strips for the water mass
    for i = 1, gridW - 1 do
        local x1 = (i-1) * spacing
        local x2 = i * spacing
        local y1 = waterNodes[i].height
        local y2 = waterNodes[i+1].height
        
        local poly = {
            { x = x1, y = y1 },
            { x = x2, y = y2 },
            { x = x2, y = sh },
            { x = x1, y = sh }
        }
        draw.NoTexture()
        surface.DrawPoly(poly)
    end

    -- Draw Surface Highlight
    surface.SetDrawColor(255, 255, 255, 100)
    for i = 1, gridW - 1 do
        local x1 = (i-1) * spacing
        local x2 = i * spacing
        surface.DrawLine(x1, waterNodes[i].height, x2, waterNodes[i+1].height)
    end

    -- Instructions
    draw.SimpleText("Click anywhere to splash the water", "DermaDefault", sw/2, centerY + 50, Color(255, 255, 255, 150), TEXT_ALIGN_CENTER)
end)
]==])

Player({{ID}}):ChatPrint("2D Water physics active. Click the screen to create waves!")
