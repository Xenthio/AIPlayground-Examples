
-- PLAN: CLIENT, Draw marquee text using HUDPaint, no cleanup needed (persistent HUD)
RunClientLua([==[
local text = "GILB LAND UNITED"
local font = "DermaLarge"
local color = Color(255, 255, 255)
local speed = 150

surface.SetFont(font)
local tw, th = surface.GetTextSize(text)

hook.Add("HUDPaint", "GilbMarquee", function()
    local sw = ScrW()
    local x = (CurTime() * speed) % (sw + tw)
    local drawX = sw - x
    
    -- Background bar
    surface.SetDrawColor(0, 0, 0, 200)
    surface.DrawRect(0, 0, sw, th + 10)
    
    -- Scrolling text
    draw.SimpleText(text, font, drawX, 5, color, TEXT_ALIGN_LEFT)
    
    -- Secondary text for seamless loop if visible
    if drawX + tw < sw then
        draw.SimpleText(text, font, drawX + sw + tw, 5, color, TEXT_ALIGN_LEFT)
    end
end)
]==])
Player(2):ChatPrint("Marquee 'GILB LAND UNITED' active.")
