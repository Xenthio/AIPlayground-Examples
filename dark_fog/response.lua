-- PLAN: server/client, use render.FogMode
RunClientLua([[
local fogColor = Color(20, 0, 0)
hook.Add("SetupWorldFog", "EvilFog", function()
    render.FogMode(MATERIAL_FOG_LINEAR)
    render.FogStart(0)
    render.FogEnd(2500)
    render.FogMaxDensity(0.95)
    render.FogColor(fogColor.r, fogColor.g, fogColor.b)
    return true
end)

hook.Add("SetupSkyboxFog", "EvilSkyFog", function()
    render.FogMode(MATERIAL_FOG_LINEAR)
    render.FogStart(0)
    render.FogEnd(1000)
    render.FogMaxDensity(1)
    render.FogColor(skyColor.r, skyColor.g, skyColor.b)
    return true
end)

timer.Simple(30, function()
    hook.Remove("SetupWorldFog", "EvilFog")
    hook.Remove("SetupSkyboxFog", "EvilSkyFog")
end)
]])
Player({{ID}}):ChatPrint("Added fog for 30 seconds!")