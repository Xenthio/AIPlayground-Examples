RunClientLua([[
hook.Add("RenderScreenspaceEffects", "CartoonEffect", function()
    DrawSobel(0.5)
    DrawColorModify({
        ["$pp_colour_addr"] = 0,
        ["$pp_colour_addg"] = 0,
        ["$pp_colour_addb"] = 0,
        ["$pp_colour_brightness"] = 0.05,
        ["$pp_colour_contrast"] = 1.4,
        ["$pp_colour_colour"] = 2,
        ["$pp_colour_mulr"] = 0,
        ["$pp_colour_mulg"] = 0,
        ["$pp_colour_mulb"] = 0,
    })
end)

timer.Simple(15, function()
    hook.Remove("RenderScreenspaceEffects", "CartoonEffect")
end)
]])

Player({{ID}}):ChatPrint("Cartoon effect active for 15 seconds!")