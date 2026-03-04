local sounds = {
    "vo/npc/male01/pain01.wav",
    "vo/npc/male01/pain02.wav",
    "vo/npc/male01/pain03.wav",
    "vo/npc/male01/pain04.wav",
    "vo/npc/male01/pain05.wav",
}

hook.Add("PlayerDeath", "DeathSound", function(victim, inflictor, attacker)
    victim:EmitSound(sounds[math.random(#sounds)])
end)

Player({{ID}}):ChatPrint("A pain sound will now play when someone dies!")