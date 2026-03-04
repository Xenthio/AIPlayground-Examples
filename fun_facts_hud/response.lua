-- PLAN: CLIENT, show a cycling fun facts display in the top-left corner.
-- Uses EHUD.AddToZone("topleft", ...) so it stacks with other corner elements
-- and never overlaps. To use a different corner: "topright" or "center".
-- NOTE: The HL2 styling here (HL2Hud fonts/colors/DrawPanel) is optional —
--       you can draw however you like inside elem:Draw(). The zone system just
--       handles positioning and stacking.
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

local CYCLE_TIME = 6
local FADE_TIME  = 0.4

local currentIdx = math.random(#FACTS)
local nextIdx    = currentIdx % #FACTS + 1
local cycleStart = CurTime()
local fadeStart  = CurTime()
local fading     = "in"
local alpha      = 0

local function advanceFact()
    currentIdx = nextIdx
    nextIdx    = currentIdx % #FACTS + 1
end

local function getLines(text, maxW, font)
    surface.SetFont(font)
    local words = string.Explode(" ", text)
    local lines, line = {}, ""
    for _, word in ipairs(words) do
        local test = line == "" and word or (line .. " " .. word)
        if surface.GetTextSize(test) > maxW and line ~= "" then
            table.insert(lines, line)
            line = word
        else
            line = test
        end
    end
    if line ~= "" then table.insert(lines, line) end
    return lines
end

local elem = {}

function elem:GetSize()
    local s = ScrH() / 480
    return math.Round(280 * s), math.Round(48 * s)
end

function elem:Draw(x, y)
    local now = CurTime()
    local s   = ScrH() / 480

    -- Fade state machine
    if fading == "in" then
        alpha = math.Clamp((now - fadeStart) / FADE_TIME, 0, 1) * 220
        if alpha >= 219 then fading = "hold"; cycleStart = now end
    elseif fading == "hold" then
        alpha = 220
        if now - cycleStart >= CYCLE_TIME then fading = "out"; fadeStart = now end
    elseif fading == "out" then
        alpha = (1 - math.Clamp((now - fadeStart) / FADE_TIME, 0, 1)) * 220
        if alpha <= 1 then advanceFact(); fading = "in"; fadeStart = now end
    end

    local C    = HL2Hud.Colors
    local pad  = math.Round(6 * s)
    local w, h = self:GetSize()
    local font = "HL2Hud_Text"
    local lineH = math.Round(10 * s)
    local lines = getLines(FACTS[currentIdx], w - pad * 2, font)

    -- Resize height to fit wrapped text
    h = pad * 2 + math.Round(12 * s) + #lines * lineH

    HL2Hud.DrawPanel(x, y, w, h,
        Color(C.BgColor.r, C.BgColor.g, C.BgColor.b, math.Round(alpha * 0.5)))

    draw.SimpleText("DID YOU KNOW?", font,
        x + pad, y + pad,
        Color(C.FgColor.r, C.FgColor.g, C.FgColor.b, math.Round(alpha)))

    for i, line in ipairs(lines) do
        draw.SimpleText(line, font,
            x + pad, y + pad + math.Round(12 * s) + (i - 1) * lineH,
            Color(255, 255, 255, math.Round(alpha)))
    end
end

-- AddToZone stacks elements in a corner without overlapping.
-- Change "topleft" to "topright" or "center" for a different position.
EHUD.AddToZone("topleft", "fun_facts", elem, 10)
]==])

Player({{ID}}):ChatPrint("Fun facts HUD active — top left corner, cycles every 6 seconds.")
