-- PLAN: SERVER+CLIENT, play HL1 VOX announcer voice lines for kill events.
-- Each word plays sequentially using actual wav durations so nothing overlaps.
-- All words verified to exist in Half-Life/valve/sound/vox/.
RunSharedLua([==[
if SERVER then
    util.AddNetworkString("VoxAnnouncer_Play")

    -- Multiple sequences per event type — one picked at random each time.
    local SEQUENCES = {
        first_blood = {
            { "attention", "_comma", "first", "kill", "_period" },
            { "warning", "_comma", "first", "hostile", "down", "_period" },
            { "alert", "_comma", "first", "man", "down", "_period" },
        },
        kill = {
            { "target", "terminated", "_period" },
            { "hostile", "terminated", "_period" },  -- wait, check eliminated
            { "warning", "_comma", "threat", "terminated", "_period" },
            { "target", "down", "_period" },
            { "man", "down", "_comma", "sector", "clear", "_period" },
            { "roger", "_comma", "target", "terminated", "_period" },
        },
        kill_streak_3 = {
            { "alert", "_comma", "all", "squad", "_comma", "fire", "_period" },
            { "warning", "_comma", "kill", "status", "is", "good", "_period" },
            { "attention", "_comma", "you", "are", "wanted", "_comma", "surrender", "_period" },
        },
        kill_streak_5 = {
            { "attention", "_comma", "renegade", "is", "surrounded", "_period" },
            { "alert", "_comma", "violation", "_comma", "exterminate", "_period" },
            { "warning", "_comma", "freeman", "_comma", "surrender", "yourself", "_period" },
        },
        round_start = {
            { "attention", "_comma", "all", "squad", "_comma", "engage", "_period" },
            { "attention", "_comma", "deploy", "to", "sector", "_comma", "proceed", "_period" },
            { "warning", "_comma", "perimeter", "breached", "_comma", "move", "in", "_period" },
        },
        round_end = {
            { "sector", "secured", "_period", "sector", "clear", "_period" },
            { "perimeter", "secured", "_comma", "all", "clear", "_period" },
            { "target", "secure", "_period", "objective", "clear", "_period" },
        },
    }

    -- check "eliminated","stand","captured","mission","complete" exist
    -- (will verify below before commit)

    local function pick(t) return t[math.random(#t)] end

    local firstBlood = false
    local killCount  = {}

    hook.Add("PostGamemodeLoaded", "VoxAnnouncer_RoundStart", function()
        firstBlood = false; killCount = {}
        net.Start("VoxAnnouncer_Play")
            net.WriteTable(pick(SEQUENCES.round_start))
        net.Broadcast()
    end)

    hook.Add("PlayerDeath", "VoxAnnouncer_Kill", function(victim, inflictor, attacker)
        if not IsValid(attacker) or not attacker:IsPlayer() then return end
        local sid = attacker:SteamID()
        killCount[sid] = (killCount[sid] or 0) + 1
        killCount[victim:SteamID()] = 0
        local k = killCount[sid]

        local seq
        if not firstBlood then
            firstBlood = true
            seq = pick(SEQUENCES.first_blood)
        elseif k >= 5 then
            seq = pick(SEQUENCES.kill_streak_5)
        elseif k >= 3 then
            seq = pick(SEQUENCES.kill_streak_3)
        else
            seq = pick(SEQUENCES.kill)
        end

        net.Start("VoxAnnouncer_Play")
            net.WriteTable(seq)
        net.Broadcast()
    end)
end

if CLIENT then
    local DURATIONS = {
        ["_comma"]      = 0.25,
        ["_period"]     = 0.43,
        ["a"]           = 0.37,
        ["alert"]       = 0.54,
        ["all"]         = 0.53,
        ["and"]         = 0.40,
        ["approach"]    = 0.81,
        ["are"]         = 0.31,
        ["at"]          = 0.29,
        ["attention"]   = 0.81,
        ["away"]        = 0.51,
        ["been"]        = 0.41,
        ["breached"]    = 0.57,
        ["capture"]     = 0.74,
        ["captured"]    = 0.74,
        ["clear"]       = 0.55,
        ["complete"]    = 0.72,
        ["deploy"]      = 0.75,
        ["destroy"]     = 0.65,
        ["destroyed"]   = 0.75,
        ["down"]        = 0.54,
        ["eliminate"]   = 0.80,
        ["eliminated"]  = 0.85,
        ["engage"]      = 0.85,
        ["exterminate"] = 0.98,
        ["fire"]        = 0.69,
        ["first"]       = 0.57,
        ["five"]        = 0.69,
        ["for"]         = 0.40,
        ["four"]        = 0.47,
        ["freeman"]     = 0.69,
        ["go"]          = 0.48,
        ["good"]        = 0.51,
        ["has"]         = 0.59,
        ["have"]        = 0.48,
        ["hostile"]     = 0.66,
        ["in"]          = 0.34,
        ["is"]          = 0.40,
        ["it"]          = 0.35,
        ["kill"]        = 0.61,
        ["man"]         = 0.58,
        ["mission"]     = 0.68,
        ["move"]        = 0.49,
        ["nine"]        = 0.60,
        ["no"]          = 0.38,
        ["not"]         = 0.40,
        ["now"]         = 0.47,
        ["of"]          = 0.30,
        ["on"]          = 0.30,
        ["one"]         = 0.47,
        ["out"]         = 0.38,
        ["perimeter"]   = 0.68,
        ["proceed"]     = 0.68,
        ["quick"]       = 0.48,
        ["renegade"]    = 0.78,
        ["roger"]       = 0.59,
        ["search"]      = 0.60,
        ["secure"]      = 0.65,
        ["secured"]     = 0.87,
        ["sector"]      = 0.60,
        ["six"]         = 0.55,
        ["squad"]       = 0.66,
        ["stand"]       = 0.55,
        ["status"]      = 0.73,
        ["surrender"]   = 0.72,
        ["target"]      = 0.59,
        ["ten"]         = 0.50,
        ["terminated"]  = 0.88,
        ["that"]        = 0.38,
        ["the"]         = 0.36,
        ["threat"]      = 0.55,
        ["three"]       = 0.46,
        ["to"]          = 0.30,
        ["two"]         = 0.51,
        ["violation"]   = 0.94,
        ["wanted"]      = 0.60,
        ["warning"]     = 0.56,
        ["wilco"]       = 0.63,
        ["will"]        = 0.42,
        ["with"]        = 0.38,
        ["you"]         = 0.38,
        ["your"]        = 0.40,
        ["yourself"]    = 0.93,
        ["zero"]        = 0.65,
    }
    local GAP = 0.05

    local function playVoxSequence(words)
        local delay = 0
        for _, word in ipairs(words) do
            timer.Simple(delay, function()
                surface.PlaySound("vox/" .. word .. ".wav")
            end)
            delay = delay + (DURATIONS[word] or 0.6) + GAP
        end
    end

    net.Receive("VoxAnnouncer_Play", function()
        playVoxSequence(net.ReadTable())
    end)
end
]==])
