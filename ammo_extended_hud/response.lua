-- HL2-style Extended Ammo Display
-- Stacks above the ammo column in EHUD's right column.
-- Shows: weapon name | clip / reserve | secondary ammo (if applicable)
-- Pulses on weapon switch. Turns red when clip is empty.
-- Uses HL2Hud.Colors for shared color theming (recolor with hud_recolor example).
if SERVER then return end

if not EHUD then include("autorun/client/cl_extensible_hud.lua") end

-- ---- Config ----------------------------------------------------------------
local HEIGHT_BASE = 36

-- ---- Helper: get current ammo info ----------------------------------------
local function getAmmoInfo()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return nil end
    local wpn = ply:GetActiveWeapon()
    if not IsValid(wpn) then return nil end
    if wpn:GetPrimaryAmmoType() == -1 then return nil end

    local clip    = wpn:Clip1()
    local maxClip = wpn:GetMaxClip1()
    local hasClip = maxClip ~= -1
    local reserve = hasClip and ply:GetAmmoCount(wpn:GetPrimaryAmmoType()) or -1
    local secType = wpn:GetSecondaryAmmoType()
    local secondary = secType ~= -1 and ply:GetAmmoCount(secType) or nil
    local name = string.upper(wpn:GetPrintName() or wpn:GetClass())
    if #name > 12 then name = string.sub(name, 1, 12) end

    return { clip=clip, reserve=reserve, secondary=secondary, name=name, hasClip=hasClip }
end

-- ---- State -----------------------------------------------------------------
local lastWeapon, lastWeaponTime = nil, 0
local lastClip,   lastClipTime   = 0,   0

-- ---- Element ---------------------------------------------------------------
local elem = {}

function elem:GetSize()
    local info = getAmmoInfo()
    local s = ScrH() / 480
    if not info then return 102*s, 0 end
    return (info.secondary and 132 or 102) * s, HEIGHT_BASE * s
end

function elem:Draw(x, y, clip_h)
    local info = getAmmoInfo()
    if not info then return end

    local s   = ScrH() / 480
    local w   = (info.secondary and 132 or 102) * s
    local h   = HEIGHT_BASE * s
    local now = CurTime()
    local C   = HL2Hud and HL2Hud.Colors or {}
    local yellow  = C.FgColor    or Color(255, 220, 0, 255)
    local red     = C.DamagedFg  or Color(255,   0, 0, 230)
    local bgCol   = C.BgColor    or Color(0,     0, 0,  76)

    -- Weapon change detection
    local ply = LocalPlayer()
    local wpn = IsValid(ply) and ply:GetActiveWeapon() or nil
    if wpn ~= lastWeapon     then lastWeapon = wpn; lastWeaponTime = now end
    if info.clip ~= lastClip then lastClip = info.clip; lastClipTime = now end

    -- Background: pulse on weapon switch
    local timeSinceWpn = now - lastWeaponTime
    local bg = bgCol
    if timeSinceWpn < 0.5 then
        local t = (1 - timeSinceWpn / 0.5) ^ 2
        local pulse = C.BrightFg or Color(255, 220, 0, 100)
        bg = Color(Lerp(t, bg.r, pulse.r), Lerp(t, bg.g, pulse.g),
                   Lerp(t, bg.b, pulse.b), Lerp(t, bg.a, 100))
    end

    local isEmpty = info.hasClip and info.clip == 0
    local textCol = isEmpty and red or yellow

    draw.RoundedBox(8, x, y, w, h, bg)

    -- Weapon name
    surface.SetFont("HL2Hud_Text")
    surface.SetTextColor(textCol)
    surface.SetTextPos(x + 8*s, y + 3*s)
    surface.DrawText(info.name)

    -- Primary clip
    local clipStr = info.hasClip and tostring(info.clip) or "–"
    local numX, numY = x + 44*s, y + 2*s

    -- Glow on clip change
    local ts = now - lastClipTime
    local glowA = 0
    if isEmpty then glowA = 255
    elseif ts < 0.1 then glowA = 255 * (ts / 0.1)
    elseif ts < 2.1 then glowA = 255 * (1 - ((ts-0.1)/2.0)^2)
    end

    if glowA > 0 then
        surface.SetFont("HL2Hud_NumbersGlow")
        surface.SetTextColor(Color(textCol.r, textCol.g, textCol.b, glowA))
        surface.SetTextPos(numX, numY)
        surface.DrawText(clipStr)
    end
    surface.SetFont("HL2Hud_Numbers")
    surface.SetTextColor(textCol)
    surface.SetTextPos(numX, numY)
    surface.DrawText(clipStr)

    -- Reserve
    if info.reserve ~= -1 then
        surface.SetFont("HL2Hud_NumbersSmall")
        surface.SetTextColor(Color(textCol.r, textCol.g, textCol.b, 180))
        surface.SetTextPos(x + 8*s, y + 20*s)
        surface.DrawText("/" .. tostring(info.reserve))
    end

    -- Secondary
    if info.secondary then
        surface.SetFont("HL2Hud_NumbersSmall")
        surface.SetTextColor(Color(textCol.r, textCol.g, textCol.b, 200))
        surface.SetTextPos(x + 98*s, y + 16*s)
        surface.DrawText(tostring(info.secondary))
    end

    return w, h
end

EHUD.AddToColumn("ammo", "ammo_extended", elem, 10)
