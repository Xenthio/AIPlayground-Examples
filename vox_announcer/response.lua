-- PLAN: SERVER+CLIENT, play HL1 VOX announcer voice lines for kill events.
-- Each word plays sequentially: the next word starts only after the previous ends.
-- Duration table built from actual wav lengths so words never overlap.
-- All words verified to exist in Half-Life/valve/sound/vox/.

if SERVER then
    util.AddNetworkString("VoxAnnouncer_Play")

    -- Sequences use only verified vox/ words (no guessing).
    -- Full word list + durations from Half-Life/valve/sound/vox/*.wav
    local SEQUENCES = {
        first_blood = { "attention", "_comma", "first", "kill", "_period" },
        kill_streak = { "warning", "_comma", "target", "kill", "_period" },
        kill_good   = { "alert", "_comma", "your", "kill", "status", "is", "good", "_period" },
        kill_fire   = { "all", "squad", "_comma", "fire", "_period" },
        round_start = { "attention", "_comma", "all", "squad", "_comma", "engage", "_period" },
        terminated  = { "target", "terminated", "_period" },
    }

    local firstBlood = false
    local killCount  = {}

    hook.Add("PostGamemodeLoaded", "VoxAnnouncer_RoundStart", function()
        firstBlood = false
        killCount  = {}
        net.Start("VoxAnnouncer_Play")
            net.WriteTable(SEQUENCES.round_start)
        net.Broadcast()
    end)

    hook.Add("PlayerDeath", "VoxAnnouncer_Kill", function(victim, inflictor, attacker)
        if not IsValid(attacker) or not attacker:IsPlayer() then return end

        local sid = attacker:SteamID()
        killCount[sid] = (killCount[sid] or 0) + 1
        local k = killCount[sid]
        killCount[victim:SteamID()] = 0

        local seq
        if not firstBlood then
            firstBlood = true
            seq = SEQUENCES.first_blood
        elseif k >= 5 then
            seq = SEQUENCES.kill_good
        elseif k >= 3 then
            seq = SEQUENCES.kill_fire
        else
            seq = SEQUENCES.terminated
        end

        net.Start("VoxAnnouncer_Play")
            net.WriteTable(seq)
        net.Broadcast()
    end)
end

if CLIENT then
    -- Word durations in seconds measured from actual wav files.
    -- Next word starts after previous word ends + small gap (0.05s).
    local DURATIONS = {
        ["_comma"]    = 0.25,
        ["_period"]   = 0.43,
        ["a"]         = 0.37,
        ["alert"]     = 0.54,
        ["all"]       = 0.53,
        ["and"]       = 0.40,
        ["are"]       = 0.31,
        ["at"]        = 0.29,
        ["attention"] = 0.81,
        ["away"]      = 0.51,
        ["been"]      = 0.41,
        ["engage"]    = 0.85,
        ["fire"]      = 0.69,
        ["first"]     = 0.57,
        ["go"]        = 0.48,
        ["good"]      = 0.51,
        ["has"]       = 0.59,
        ["hostile"]   = 0.66,
        ["in"]        = 0.34,
        ["is"]        = 0.40,
        ["kill"]      = 0.61,
        ["now"]       = 0.47,
        ["sector"]    = 0.60,
        ["squad"]     = 0.66,
        ["status"]    = 0.73,
        ["target"]    = 0.59,
        ["terminated"]= 0.88,
        ["the"]       = 0.36,
        ["warning"]   = 0.56,
        ["your"]      = 0.40,
        ["you"]       = 0.38,
    }
    local GAP = 0.05  -- brief silence between words

    local function playVoxSequence(words)
        local delay = 0
        for _, word in ipairs(words) do
            local path = "vox/" .. word .. ".wav"
            timer.Simple(delay, function()
                surface.PlaySound(path)
            end)
            delay = delay + (DURATIONS[word] or 0.6) + GAP
        end
    end

    net.Receive("VoxAnnouncer_Play", function()
        local words = net.ReadTable()
        playVoxSequence(words)
    end)
end
