
RunClientLua([[
-- NOTE TO AI:
-- This is a template! You can modify it, it's just a set of rules so it WORKS.
-- IMPORTANT: Ensure it WORKS always.
-- ALWAYS KEEP THE ONMOUSEPRESSED FUNCTION!
if myChat and myChat.frame and IsValid(myChat.frame) then myChat.frame:Remove() end
myChat = {}
myChat.isOpen = false
myChat.isTeam = false

-- Frame
myChat.frame = vgui.Create("DFrame")
myChat.frame:SetSize(520, 300)
myChat.frame:SetPos(20, ScrH() - 320)
myChat.frame:SetTitle("")
myChat.frame:ShowCloseButton(false)
myChat.frame:SetDraggable(true)
myChat.frame:SetVisible(false)
myChat.frame:SetMouseInputEnabled(false)
myChat.frame:SetKeyboardInputEnabled(false)
myChat.frame.Paint = function(s, w, h)
    if not myChat.isOpen then return end
    draw.RoundedBox(8, 0, 0, w, h, Color(25, 25, 25, 210))
end
myChat.frame.OnMousePressed = function(s, code)
    myChat.entry:RequestFocus()
end

-- Messages
myChat.richText = vgui.Create("RichText", myChat.frame)
myChat.richText:Dock(FILL)
myChat.richText:DockMargin(6, 6, 6, 4)
myChat.richText.PerformLayout = function(s) s:SetFontInternal("ChatFont") end

-- Input bar
myChat.bottom = vgui.Create("DPanel", myChat.frame)
myChat.bottom:Dock(BOTTOM)
myChat.bottom:DockMargin(6, 0, 6, 6)
myChat.bottom:SetTall(26)
myChat.bottom.Paint = function(s, w, h)
    if myChat.isOpen then draw.RoundedBox(4, 0, 0, w, h, Color(15, 15, 15, 180)) end
end

myChat.label = vgui.Create("DLabel", myChat.bottom)
myChat.label:Dock(LEFT)
myChat.label:DockMargin(8, 0, 4, 0)
myChat.label:SetWide(50)
myChat.label:SetFont("ChatFont")

myChat.entry = vgui.Create("DTextEntry", myChat.bottom)
myChat.entry:Dock(FILL)
myChat.entry:DockMargin(0, 2, 4, 2)
myChat.entry:SetFont("ChatFont")
myChat.entry:SetDrawBackground(false)
myChat.entry:SetTextColor(color_white)
myChat.entry:SetCursorColor(color_white)

function myChat.open(bTeam)
    myChat.isOpen = true
    myChat.isTeam = bTeam or false
    myChat.label:SetText(bTeam and "Team:" or "Say:")
    myChat.label:SetColor(bTeam and Color(130, 220, 130) or Color(200, 200, 200))
    myChat.frame:SetVisible(true)
    myChat.frame:MakePopup()
    myChat.entry:RequestFocus()
    myChat.richText:GotoTextEnd()
    hook.Run("StartChat", bTeam)
end

function myChat.close()
    myChat.isOpen = false
    myChat.frame:SetVisible(false)
    myChat.frame:SetMouseInputEnabled(false)
    myChat.frame:SetKeyboardInputEnabled(false)
    gui.EnableScreenClicker(false)
    hook.Run("FinishChat")
    myChat.entry:SetText("")
    hook.Run("ChatTextChanged", "")
end

myChat.entry.OnKeyCodeTyped = function(s, code)
    if code == KEY_ESCAPE then
        myChat.close()
        gui.HideGameUI()
    elseif code == KEY_ENTER then
        local text = string.Trim(s:GetText())
        if text ~= "" and LocalPlayer():Alive() then
            LocalPlayer():ConCommand(myChat.isTeam and "say_team " or "say " .. text)
        end
        myChat.close()
    end
end

myChat.entry.OnValueChange = function(s, text) hook.Run("ChatTextChanged", text) end

-- Override chat.AddText
myChat.oldAddText = myChat.oldAddText or chat.AddText
function chat.AddText(...)
    for _, obj in ipairs({...}) do
        if IsColor(obj) or (istable(obj) and obj.r) then
            myChat.richText:InsertColorChange(obj.r, obj.g, obj.b, 255)
        elseif isstring(obj) then
            myChat.richText:AppendText(obj)
        elseif IsValid(obj) and obj:IsPlayer() then
            local col = team.GetColor(obj:Team()) or Color(200, 200, 200)
            myChat.richText:InsertColorChange(col.r, col.g, col.b, 255)
            myChat.richText:AppendText(obj:Nick())
        end
    end
    myChat.richText:AppendText("\n")
    myChat.richText:GotoTextEnd()

    if not myChat.isOpen then
        myChat.frame:SetVisible(true)
        timer.Create("myChatFade", 8, 1, function()
            if not myChat.isOpen and IsValid(myChat.frame) then myChat.frame:SetVisible(false) end
        end)
    end
    myChat.oldAddText(...)
end

hook.Add("PlayerBindPress", "myChat_Bind", function(ply, bind, pressed)
    if not pressed then return end
    if bind == "messagemode" then myChat.open(false) return true
    elseif bind == "messagemode2" then myChat.open(true) return true
    elseif myChat.isOpen and (bind == "+menu" or bind == "cancelselect") then
        myChat.close()
        return true
    end
end)

hook.Add("ChatText", "myChat_Server", function(index, name, text, msgType)
    if msgType == "joinleave" or msgType == "none" then
        myChat.richText:InsertColorChange(180, 180, 180, 255)
        myChat.richText:AppendText(text .. "\n")
    end
end)

hook.Add("HUDShouldDraw", "myChat_Hide", function(name)
    if name == "CHudChat" then return false end
end)

chat.AddText(Color(80, 200, 120), "[Chat] ", color_white, "Custom chatbox loaded!")
]])

Player({{ID}}):ChatPrint("Custom chatbox installed!")