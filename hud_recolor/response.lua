-- PLAN: CLIENT, recolor the HL2 HUD by updating HL2Hud.Colors fields.
-- GilbUtils automatically loads the HL2 HUD replacement (cl_hl2_hud.lua),
-- so HL2Hud is always available. Just update the color fields and call ApplyColors().
--
-- Available color fields:
--   HL2Hud.Colors.FgColor          — main number/text color
--   HL2Hud.Colors.BrightFg         — flash color on health/suit change
--   HL2Hud.Colors.DamagedFg        — color when health is low
--   HL2Hud.Colors.BrightDamagedFg  — peak pulse color when health is low
--   HL2Hud.Colors.BgColor          — panel background
--   HL2Hud.Colors.DamagedBg        — background pulse when health is low
--   HL2Hud.Colors.AuxHigh          — aux bar color (normal)
--   HL2Hud.Colors.AuxLow           — aux bar color when below 25%
--   HL2Hud.Colors.AuxDisabled      — alpha for unfilled aux chunks (number 0-255)
--
-- IMPORTANT: always call HL2Hud.ApplyColors() after changing colors.
-- Without it, changes only take effect when animations fire (e.g. taking damage).
RunClientLua([==[
if not HL2Hud then
    print("[HUD Recolor] HL2Hud not found — GilbUtils may not be loaded.")
    return
end

HL2Hud.Colors.FgColor         = Color( 80, 180, 255, 255)
HL2Hud.Colors.BrightFg        = Color(180, 220, 255, 255)
HL2Hud.Colors.DamagedFg       = Color(255,  60,  60, 230)
HL2Hud.Colors.BrightDamagedFg = Color(255, 120, 120, 255)
HL2Hud.Colors.BgColor         = Color(  0,  20,  60,  76)
HL2Hud.Colors.DamagedBg       = Color(120,   0,   0, 200)
HL2Hud.Colors.AuxHigh         = Color( 80, 180, 255, 220)
HL2Hud.Colors.AuxLow          = Color(255,  60,  60, 220)
HL2Hud.Colors.AuxDisabled     = 60
HL2Hud.ApplyColors()
]==])
Player({{ID}}):ChatPrint("HUD recolored.")
