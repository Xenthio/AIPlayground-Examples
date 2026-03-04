
-- REALM: CLIENT
-- DESCRIPTION: A sleek, professional ESP featuring animated health bars, distance scaling, and clean typography.
-- CLEANUP: Run the code again to overwrite or use 'hook.Remove("HUDPaint", "SleekProfessionalESP")' in console.

RunClientLua([==[
local esp_font = "SleekESP_Font"
surface.CreateFont(esp_font, {
    font = "Roboto", 
    size = 16,
    weight = 500,
    antialias = true,
})

local function DrawCornerBox(x, y, w, h, thickness, color)
    local length = math.min(w, h) * 0.2
    surface.SetDrawColor(color)
    
    -- Top Left
    surface.DrawRect(x, y, length, thickness)
    surface.DrawRect(x, y, thickness, length)
    
    -- Top Right
    surface.DrawRect(x + w - length, y, length, thickness)
    surface.DrawRect(x + w - thickness, y, thickness, length)
    
    -- Bottom Left
    surface.DrawRect(x, y + h - thickness, length, thickness)
    surface.DrawRect(x, y + h - length, thickness, length)
    
    -- Bottom Right
    surface.DrawRect(x + w - length, y + h - thickness, length, thickness)
    surface.DrawRect(x + w - thickness, y + h - length, thickness, length)
end

hook.Add("HUDPaint", "SleekProfessionalESP", function()
    local lp = LocalPlayer()
    
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() or ply == lp or ply:GetNoDraw() then continue end
        
        local pos = ply:GetPos()
        local top = pos + Vector(0, 0, ply:GetModelRadius() * 1.5) -- Dynamic height based on model
        local screenPos = pos:ToScreen()
        local screenTop = top:ToScreen()
        
        if screenPos.visible then
            local dist = lp:GetPos():Distance(pos)
            local alpha = math.Clamp(255 - (dist / 4000) * 255, 0, 255)
            if alpha <= 0 then continue end

            local h = math.abs(screenPos.y - screenTop.y)
            local w = h * 0.6
            local x = screenPos.x - w / 2
            local y = screenTop.y
            
            -- Box Shadow / Background
            DrawCornerBox(x - 1, y - 1, w + 2, h + 2, 3, Color(0, 0, 0, alpha * 0.6))
            -- Main Corner Box
            local teamCol = team.GetColor(ply:Team())
            DrawCornerBox(x, y, w, h, 1, Color(teamCol.r, teamCol.g, teamCol.b, alpha))
            
            -- Health Bar (Left Side)
            local hp = math.Clamp(ply:Health(), 0, ply:GetMaxHealth())
            local hpPerc = hp / ply:GetMaxHealth()
            local barH = h * hpPerc
            local barCol = Color((1 - hpPerc) * 255, hpPerc * 255, 0, alpha)
            
            surface.SetDrawColor(0, 0, 0, alpha * 0.5)
            surface.DrawRect(x - 6, y, 4, h) -- Background
            surface.SetDrawColor(barCol)
            surface.DrawRect(x - 6, y + h - barH, 4, barH) -- Fill
            
            -- Text Info (Right Side)
            local textX = x + w + 6
            local name = ply:Nick()
            local weapon = IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon():GetPrintName() or "None"
            local dText = math.Round(dist * 0.019, 1) .. "m"
            
            draw.SimpleTextOutlined(name, esp_font, textX, y, Color(255, 255, 255, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, alpha))
            draw.SimpleTextOutlined(weapon, esp_font, textX, y + 16, Color(200, 200, 200, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, alpha))
            draw.SimpleTextOutlined(dText, esp_font, textX, y + 32, Color(150, 150, 150, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, alpha))
            
            -- Small visual indicator for health if low
            if hpPerc < 0.3 then
                draw.SimpleTextOutlined("LOW HP", esp_font, x + w/2, y - 20, Color(255, 50, 50, alpha * (math.sin(CurTime() * 10) + 1)), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, alpha))
            end
        end
    end
end)
]==])

Player({{ID}}):ChatPrint("Sleek Professional ESP initialized. Features corner boxes, distance scaling, and health bars.")
