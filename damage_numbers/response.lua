-- PLAN: SERVER+CLIENT, floating damage numbers above hit entities.
-- Server half uses RunSharedLua (runs on server) to register the net string and hook.
-- Client half uses RunClientLua to receive and render the floating numbers.
RunSharedLua([==[
if SERVER then
    util.AddNetworkString("DamageNumbers_Hit")

    hook.Add("EntityTakeDamage", "DamageNumbers_Damage", function(ent, dmginfo)
        local dmg = math.Round(dmginfo:GetDamage())
        if dmg <= 0 then return end
        if not IsValid(ent) then return end

        local pos = ent:GetPos() + Vector(
            math.Rand(-12, 12),
            math.Rand(-12, 12),
            ent:BoundingRadius() * 0.8
        )

        local isHeadshot = dmginfo:IsDamageType(DMG_BULLET)
            and ent:IsPlayer() and ent:Health() - dmg <= 0

        net.Start("DamageNumbers_Hit")
            net.WriteVector(pos)
            net.WriteInt(dmg, 16)
            net.WriteBool(isHeadshot)
        net.Broadcast()
    end)
end
]==])

RunClientLua([==[
local numbers  = {}
local LIFETIME = 1.2
local FADE_AT  = 0.7
local FLOAT    = 40

net.Receive("DamageNumbers_Hit", function()
    table.insert(numbers, {
        pos  = net.ReadVector(),
        dmg  = net.ReadInt(16),
        head = net.ReadBool(),
        born = CurTime(),
    })
end)

hook.Add("DrawTranslucent", "DamageNumbers_Draw", function()
    local now  = CurTime()
    local keep = {}
    for _, n in ipairs(numbers) do
        local age = now - n.born
        if age > LIFETIME then continue end

        local frac  = age / LIFETIME
        local alpha = frac > FADE_AT
            and math.Round(255 * (1 - (frac - FADE_AT) / (1 - FADE_AT)))
            or  255
        local scale    = frac < 0.1 and Lerp(frac / 0.1, 1.6, 1.0) or 1.0
        local floatPos = n.pos + Vector(0, 0, age * FLOAT)

        local col
        if n.head        then col = Color(255, 80,  80,  alpha)
        elseif n.dmg>=50 then col = Color(255, 200, 0,   alpha)
        else                  col = Color(255, 255, 255, alpha) end

        local ang = (EyePos() - floatPos):Angle()
        ang:RotateAroundAxis(ang:Right(), 90)
        ang:RotateAroundAxis(ang:Up(), -90)

        cam.Start3D2D(floatPos, ang, 0.12 * scale)
            draw.SimpleText(
                (n.head and "* " or "") .. tostring(n.dmg),
                "HL2Hud_Numbers", 0, 0, col,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()

        table.insert(keep, n)
    end
    numbers = keep
end)
]==])

Player({{ID}}):ChatPrint("Damage numbers active.")
