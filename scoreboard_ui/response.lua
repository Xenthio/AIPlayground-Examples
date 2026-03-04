RunClientLua([[
local frame = vgui.Create("DFrame")
frame:SetSize(400, 300)
frame:Center()
frame:SetTitle("Scoreboard")
frame:MakePopup()

local html = vgui.Create("DHTML", frame)
html:Dock(FILL)

local rows = ""
for _, ply in ipairs(player.GetAll()) do
    rows = rows .. "<tr><td>" .. ply:Nick() .. "</td><td>" .. ply:Frags() .. "</td><td>" .. ply:Deaths() .. "</td></tr>"
end

html:SetHTML([==[
<html><head><style>
body { background:#1a1a2e; color:#eee; font-family:Arial; margin:0; padding:10px; }
table { width:100%; border-collapse:collapse; }
th { background:#16213e; padding:8px; text-align:left; }
td { padding:6px; border-bottom:1px solid #333; }
</style></head><body>
<table><tr><th>Player</th><th>Kills</th><th>Deaths</th></tr>]==] .. rows .. [==[</table>
</body></html>
]==])
]])

Player({{ID}}):ChatPrint("Opened the scoreboard!")