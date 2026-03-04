hook.Add("EntityFireBullets", "ExplodingBullets", function(ent, data)
    local oldCallback = data.Callback
    data.Callback = function(attacker, tr, dmginfo)
        if oldCallback then oldCallback(attacker, tr, dmginfo) end
        local explosion = ents.Create("env_explosion")
        explosion:SetPos(tr.HitPos)
        explosion:SetOwner(attacker)
        explosion:Spawn()
        explosion:SetKeyValue("iMagnitude", "100")
        explosion:Fire("Explode", 0, 0)
    end
end)

Player({{ID}}):ChatPrint("All bullets will now explode on impact!")