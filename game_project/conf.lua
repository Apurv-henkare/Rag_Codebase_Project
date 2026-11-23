--[[
    Inflate - LÖVE configuration
]]

function love.conf(t)
    t.identity = 'inflate'          -- save folder name
    t.version = '11.3'
    t.window.title = 'Inflate'
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = true
    t.window.minwidth = 320
    t.window.minheight = 180
    t.window.vsync = 1
    -- draw at the screen's real pixel resolution (phones / web), so the
    -- pixel art stays sharp instead of being stretched by the browser
    t.window.highdpi = true

    -- modules we don't need
    t.modules.joystick = false
    t.modules.physics = false
    t.modules.video = false
end
