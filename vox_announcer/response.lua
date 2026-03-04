-- PLAN: SERVER+CLIENT, play HL1 VOX announcer voice lines for kill events.
-- VOX system: sequences of vox/*.wav files played client-side with small gaps
-- between words, exactly like HL1/TFC does it (CHAN_STATIC equivalent = no channel
-- conflict with player voice, uses EmitSound with CHAN_STATIC = 8).
-- Words from Half-Life/valve/sound/vox/ — must be mounted (HL1 in game library).
-- Net message broadcasts which sequence to play to all clients.

-- SERVER: detect kills, broadcast VOX sequences
if SERVER then
    util.AddNetworkString("VoxAnnouncer_Play")

    -- VOX word sequences for events.
    -- Words are filenames from sound/vox/ without the .wav extension.
    -- "_comma" and "_period" add brief pauses (they're actual audio files).
    local SEQUENCES = {
        first_blood   = { "attention", "_comma", "first", "kill", "_period" },
        kill_2        = { "warning", "_comma", "hostile", "eliminated", "_period" },
        kill_3        = { "alert", "_comma", "kill", "squad", "_period" },
        kill_5        = { "attention", "_comma", "your", "kill", "status", "_period", "is", "good", "_period" },
        round_start   = { "attention", "_comma", "all", "squad", "_comma", "engage", "_period" },
        round_end     = { "mission", "_comma", "complete", "_period" },
    }
    -- Note: use only words that exist in sound/vox/ as .wav files.
    -- Full list: ls Half-Life/valve/sound/vox/

    local firstBlood   = false
    local killStreaks   = {}  -- steamid -> count

    hook.Add("PostGamemodeLoaded", "VoxAnnouncer_RoundStart", function()
        firstBlood = false
        killStreaks = {}
        -- Broadcast round start sequence to all clients
        net.Start("VoxAnnouncer_Play")
            net.WriteString("round_start")
            net.WriteTable(SEQUENCES.round_start)
        net.Broadcast()
    end)

    hook.Add("PlayerDeath", "VoxAnnouncer_Kill", function(victim, inflictor, attacker)
        if not IsValid(attacker) or not attacker:IsPlayer() then return end

        local sid = attacker:SteamID()
        killStreaks[sid] = (killStreaks[sid] or 0) + 1
        local streak = killStreaks[sid]

        local seqName, seq
        if not firstBlood then
            firstBlood = true
            seqName, seq = "first_blood", SEQUENCES.first_blood
        elseif streak >= 5 then
            seqName, seq = "kill_5", SEQUENCES.kill_5
        elseif streak >= 3 then
            seqName, seq = "kill_3", SEQUENCES.kill_3
        else
            seqName, seq = "kill_2", SEQUENCES.kill_2
        end

        net.Start("VoxAnnouncer_Play")
            net.WriteString(seqName)
            net.WriteTable(seq)
        net.Broadcast()

        -- Reset streak on death
        local vsid = victim:SteamID()
        killStreaks[vsid] = 0
    end)
end

-- CLIENT: receive and play VOX sequences
if CLIENT then
    -- Gap between words in seconds (HL1 used ~0.1s, feels natural at 0.08-0.15)
    local WORD_GAP = 0.1
    -- VOX path prefix (Half-Life mounted content)
    local VOX_PREFIX = "vox/"

    local function playVoxSequence(words)
        local delay = 0
        for _, word in ipairs(words) do
            local path = VOX_PREFIX .. word .. ".wav"
            timer.Simple(delay, function()
                -- CHAN_STATIC (8) matches HL1 behavior: doesn't interrupt other sounds
                surface.PlaySound(path)
            end)
            -- Pause words add extra gap, normal words add standard gap
            if word == "_comma" then
                delay = delay + 0.3
            elseif word == "_period" then
                delay = delay + 0.4
            else
                delay = delay + WORD_GAP
            end
        end
    end

    net.Receive("VoxAnnouncer_Play", function()
        local seqName = net.ReadString()
        local words   = net.ReadTable()
        playVoxSequence(words)
    end)
end
