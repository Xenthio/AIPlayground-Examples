-- PLAN: CLIENT, show a cycling fun facts display in the top-left corner.
-- Draws directly in HUDPaint — no EHUD column needed for corner overlays.
-- NOTE: This example uses HL2 styling (HL2Hud fonts/colors/DrawPanel) but you
--       don't have to! Corner overlays can use any fonts, colors, or drawing style
--       you like — just hook HUDPaint and draw at the screen position you want.
RunClientLua([==[
local FACTS = {
    "A shrimp's heart is in its head.",
    "Honey never spoils. Archaeologists found 3000-year-old honey in Egyptian tombs.",
    "Bananas are berries. Strawberries are not.",
    "A group of flamingos is called a flamboyance.",
    "Wombat poop is cube-shaped.",
    "Crows can recognize human faces and hold grudges.",
    "There are more possible chess games than atoms in the observable universe.",
    "Octopuses have three hearts and blue blood.",
    "The Eiffel Tower grows 15cm taller in summer due to heat expansion.",
    "A day on Venus is longer than a year on Venus.",
    "Sea otters hold hands while sleeping so they don't drift apart.",
    "Cleopatra lived closer in time to the Moon landing than to the construction of the Great Pyramid.",
}

local CYCLE_TIME = 6   -- seconds per fact
local FADE_TIME  = 0.4 -- fade in/out duration

local currentIdx = math.random(#FACTS)
local nextIdx    = nil
local cycleStart = CurTime()
local alpha      = 0   -- 0..255
local fading     = "in"  -- "in" | "hold" | "out"
local fadeStart  = CurTime()

local function nextFact()
    repeat nextIdx = math.random(#FACTS) until nextIdx ~= currentIdx
end
nextFact()

hook.Add("HUDPaint", "FunFactsHud", function()
    if not HL2Hud.enabled then return end  -- respects hl2hud_toggle

    local now = CurTime()
    local s   = ScrH() / 480

    -- State machine: fade in → hold → fade out → advance → fade in
    if fading == "in" then
        local t = math.Clamp((now - fadeStart) / FADE_TIME, 0, 1)
        alpha = math.Round(t * 220)
        if t >= 1 then fading = "hold"; cycleStart = now end

    elseif fading == "hold" then
        alpha = 220
        if now - cycleStart >= CYCLE_TIME then
            fading = "out"; fadeStart = now
        end

    elseif fading == "out" then
        local t = math.Clamp((now - fadeStart) / FADE_TIME, 0, 1)
        alpha = math.Round((1 - t) * 220)
        if t >= 1 then
            currentIdx = nextIdx
            nextFact()
            fading = "in"; fadeStart = now
        end
    end

    local C    = HL2Hud.Colors
    local pad  = math.Round(8 * s)
    local maxW = math.Round(280 * s)

    -- Measure text to size the panel
    surface.SetFont("HL2Hud_Text")
    local tw, th = surface.GetTextSize(FACTS[currentIdx])
    -- Wrap long facts to maxW
    local lines = {}
    local words = string.Explode(" ", FACTS[currentIdx])
    local line  = ""
    for _, word in ipairs(words) do
        local test = line == "" and word or (line .. " " .. word)
        local lw   = surface.GetTextSize(test)
        if lw > maxW - pad*2 and line ~= "" then
            table.insert(lines, line)
            line = word
        else
            line = test
        end
    end
    if line ~= "" then table.insert(lines, line) end

    local lineH = math.Round(10 * s)
    local boxW  = maxW
    local boxH  = math.Round(14*s) + #lines * lineH + pad

    -- Top-left corner position (change these to put it in any corner)
    -- Top-right:   x = ScrW() - boxW - pad
    -- Bottom-left: y = ScrH() - boxH - pad
    local bx = pad
    local by = pad

    -- Draw panel background (HL2-styled — swap this for any style you want)
    HL2Hud.DrawPanel(bx, by, boxW, boxH, Color(C.BgColor.r, C.BgColor.g, C.BgColor.b, math.Round(alpha * 0.5)))

    -- "DID YOU KNOW?" header
    local col = Color(C.FgColor.r, C.FgColor.g, C.FgColor.b, alpha)
    draw.SimpleText("DID YOU KNOW?", "HL2Hud_Text", bx + pad, by + pad, col)

    -- Fact lines
    surface.SetFont("HL2Hud_Text")
    for i, l in ipairs(lines) do
        local lCol = Color(255, 255, 255, alpha)
        draw.SimpleText(l, "HL2Hud_Text",
            bx + pad, by + pad + math.Round(12*s) + (i-1) * lineH, lCol)
    end
end)

Player({{ID}}):ChatPrint("Fun facts HUD active — top left corner, cycles every 6 seconds.")
]==])
