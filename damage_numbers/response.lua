-- PLAN: SERVER+CLIENT, floating damage numbers above hit entities.
-- Server detects damage, sends net message with position + amount.
-- Client renders numbers as 3D2D text that float upward and fade out.

if SERVER then
    util.AddNetworkString("DamageNumbers_Hit")

    hook.Add("EntityTakeDamage", "DamageNumbers_Damage", function(ent, dmginfo)
        local dmg = math.Round(dmginfo.GetDamage and dmginfo:GetDamage() or 0)
        if dmg <= 0 then return end
        if not IsValid(ent) then return end

        -- Spawn above the hit position (or entity center)
        local pos = ent:GetPos() + Vector(0, 0, ent:BoundingRadius() * 0.8)
        -- Scatter slightly so multiple hits don't stack
        pos = pos + Vector(math.Rand(-12, 12), math.Rand(-12, 12), 0)

        local isHeadshot = dmginfo:IsDamageType(DMG_BULLET) and ent:IsPlayer()
            and ent:Health() <= 0

        net.Start("DamageNumbers_Hit")
            net.WriteVector(pos)
            net.WriteInt(dmg, 16)
            net.WriteBool(isHeadshot)
        net.Broadcast()
    end)
end

if CLIENT then
    local numbers = {}  -- active floating numbers

    local FLOAT_SPEED  = 40   -- units/sec upward
    local LIFETIME     = 1.2  -- seconds total
    local FADE_START   = 0.7  -- fade begins at this fraction of lifetime

    net.Receive("DamageNumbers_Hit", function()
        local pos       = net.ReadVector()
        local dmg       = net.ReadInt(16)
        local headshot  = net.ReadBool()
        table.insert(numbers, {
            pos     = pos,
            dmg     = dmg,
            born    = CurTime(),
            head    = headshot,
        })
    end)

    hook.Add("DrawTranslucent", "DamageNumbers_Draw", function()
        local now  = CurTime()
        local keep = {}

        for _, n in ipairs(numbers) do
            local age  = now - n.born
            if age > LIFETIME then continue end

            -- Float upward
            local floatPos = n.pos + Vector(0, 0, age * FLOAT_SPEED)

            -- Fade out in last portion of lifetime
            local alpha = 255
            local frac  = age / LIFETIME
            if frac > FADE_START then
                alpha = math.Round(255 * (1 - (frac - FADE_START) / (1 - FADE_START)))
            end

            -- Scale: pop in big, settle to normal
            local scale = frac < 0.1 and Lerp(frac / 0.1, 1.6, 1.0) or 1.0

            -- Color: red for headshots, yellow for high damage, white otherwise
            local col
            if n.head then
                col = Color(255, 80, 80, alpha)
            elseif n.dmg >= 50 then
                col = Color(255, 200, 0, alpha)
            else
                col = Color(255, 255, 255, alpha)
            end

            -- Face camera
            local ang = (EyePos() - floatPos):Angle()
            ang:RotateAroundAxis(ang:Right(), 90)
            ang:RotateAroundAxis(ang:Up(), -90)

            cam.Start3D2D(floatPos, ang, 0.1 * scale)
                draw.SimpleText(
                    (n.head and "★ " or "") .. tostring(n.dmg),
                    "HL2Hud_Numbers",
                    0, 0, col,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
                )
            cam.End3D2D()

            table.insert(keep, n)
        end

        numbers = keep
    end)
end
