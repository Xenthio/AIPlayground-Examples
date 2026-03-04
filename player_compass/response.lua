-- PLAN: CLIENT, compass strip at the top showing cardinal directions and player markers.
-- A horizontal strip showing N/S/E/W labels that scroll with your yaw,
-- with colored dots showing bearing to other players.
-- Uses EHUD.AddToZone("topright") so it stacks cleanly with other corner elements.
RunClientLua([==[
local STRIP_W = 300   -- width in baseline (480p) units
local STRIP_H = 18

local elem = {}

function elem:GetSize()
    local s = ScrH() / 480
    return math.Round(STRIP_W * s), math.Round(STRIP_H * s)
end

function elem:Draw(x, y)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local s   = ScrH() / 480
    local w   = math.Round(STRIP_W * s)
    local h   = math.Round(STRIP_H * s)
    local C   = HL2Hud.Colors

    -- Background
    HL2Hud.DrawPanel(x, y, w, h)

    -- Clip drawing to panel bounds
    render.SetScissorRect(x, y, x + w, y + h, true)

    local yaw = ply:EyeAngles().y  -- current look direction (degrees)

    -- Cardinal directions: N=0, E=90, S=180, W=270 (game yaw: 0=east, 90=north)
    -- GMod yaw: 0=east(+x), 90=north(+y), 180=west, -90=south
    local cardinals = {
        { label = "N", yaw = 90  },
        { label = "E", yaw = 0   },
        { label = "S", yaw = -90 },
        { label = "W", yaw = 180 },
        { label = "NE", yaw = 45  },
        { label = "SE", yaw = -45 },
        { label = "SW", yaw = -135 },
        { label = "NW", yaw = 135  },
    }

    local center = x + w / 2
    local pxPerDeg = w / 90  -- 90 degrees spans the full strip

    surface.SetFont("HL2Hud_Text")
    for _, c in ipairs(cardinals) do
        local diff = math.NormalizeAngle(c.yaw - yaw)
        if math.abs(diff) < 55 then
            local cx = center + diff * pxPerDeg
            local col = (c.label == "N" or c.label == "S" or c.label == "E" or c.label == "W")
                and Color(C.FgColor.r, C.FgColor.g, C.FgColor.b, 255)
                or  Color(200, 200, 200, 180)
            draw.SimpleText(c.label, "HL2Hud_Text", cx, y + h/2,
                col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- Player markers
    local myPos = ply:GetPos()
    for _, other in ipairs(player.GetAll()) do
        if other == ply or not other:Alive() then continue end

        local dir  = other:GetPos() - myPos
        local bear = math.deg(math.atan2(dir.y, dir.x))  -- bearing in GMod yaw space
        local diff = math.NormalizeAngle(bear - yaw)

        if math.abs(diff) < 55 then
            local mx   = center + diff * pxPerDeg
            local dist = dir:Length()
            -- Fade dots with distance (show up to 3000 units away)
            local a    = math.Round(255 * math.Clamp(1 - dist / 3000, 0.2, 1))
            surface.SetDrawColor(100, 220, 255, a)
            surface.DrawRect(mx - 2, y + h - 4*s, 4, 4*s)

            -- Name above dot if very close
            if dist < 600 then
                draw.SimpleText(other:Nick(), "HL2Hud_Text",
                    mx, y + 2*s, Color(255,255,255,a), TEXT_ALIGN_CENTER)
            end
        end
    end

    -- Center aim marker
    surface.SetDrawColor(C.FgColor.r, C.FgColor.g, C.FgColor.b, 200)
    surface.DrawRect(center - 1, y, 2, h)

    render.SetScissorRect(0, 0, 0, 0, false)
end

EHUD.AddToZone("topright", "player_compass", elem, 20)
]==])

Player({{ID}}):ChatPrint("Player compass active — top right, shows bearing to other players.")
