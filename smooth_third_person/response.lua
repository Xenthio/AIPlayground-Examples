
-- PLAN: CLIENT, use CalcView hook to offset camera behind player, use Lerp/SmoothDamp logic for smooth transition, handle trace to prevent wall clipping
RunClientLua([==[
local thirdperson_enabled = true
local cam_offset = Vector(-100, 30, 10) -- Back, Right, Up
local current_origin = Vector(0, 0, 0)
local smooth_pos = Vector(0, 0, 0)

hook.Add("CalcView", "SmoothThirdPerson", function(ply, pos, angles, fov)
    if not thirdperson_enabled then return end
    if not ply:Alive() then return end

    local target_pos = pos + (angles:Forward() * cam_offset.x) + (angles:Right() * cam_offset.y) + (angles:Up() * cam_offset.z)
    
    -- Trace to prevent clipping through walls
    local tr = util.TraceHull({
        start = pos,
        endpos = target_pos,
        filter = ply,
        mins = Vector(-8, -8, -8),
        maxs = Vector(8, 8, 8),
        mask = MASK_SHOT_HULL
    })

    local final_target = tr.HitPos
    if tr.Hit then
        final_target = tr.HitPos + tr.HitNormal * 4
    end

    -- Smooth transition
    smooth_pos = LerpVector(FrameTime() * 10, smooth_pos, final_target)

    local view = {}
    view.origin = smooth_pos
    view.angles = angles
    view.fov = fov
    view.drawviewer = true -- This makes the local player model visible

    return view
end)

-- Toggle command for the player
concommand.Add("toggle_thirdperson", function()
    thirdperson_enabled = not thirdperson_enabled
    print("Thirdperson: " .. (thirdperson_enabled and "Enabled" or "Disabled"))
end)
]==])

Player(7):ChatPrint("Smooth Third Person active. Use 'toggle_thirdperson' in console to switch.")
