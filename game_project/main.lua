--[[
    INFLATE
    A bouncing-ball platformer where air is your life.

    All art and sound are generated in code (no image or audio files).
    Plays with a keyboard or with on-screen touch buttons (phones / tablets).
]]

love.graphics.setDefaultFilter('nearest', 'nearest')
require 'src/Dependencies'

local mmin = math.min

function love.load(args)
    math.randomseed(os.time())
    SaveData.load(args)        -- (on the web, args carries the page's saved progress)

    -- whole-number scaling to any screen; portrait phones get a button panel
    Screen.init()

    gStateMachine = StateMachine {
        ['start'] = function() return StartState() end,
        ['play']  = function() return PlayState() end,
        ['art-preview'] = function() return ArtPreviewState() end,
        ['level-complete'] = function() return LevelCompleteState() end,
        ['level-select'] = function() return LevelSelectState() end,
        ['game-complete'] = function() return GameCompleteState() end,
    }
    gStateMachine:change('start')

    love.keyboard.keysPressed = {}
end

function love.resize(w, h)
    Screen.resize()
end

-- app hidden / tab switched: forget held buttons (their "lifted" messages may never come)
function love.focus(focused)
    if not focused then TouchControls.reset() end
end

function love.keypressed(key)
    love.keyboard.keysPressed[key] = true
    -- F2: test the touch buttons on PC (the mouse acts as a finger)
    if key == 'f2' then TouchControls.toggleEmulation() end
end

function love.keyboard.wasPressed(key)
    return love.keyboard.keysPressed[key] == true
end

-- game actions -> keys (change controls here)
INPUT_KEYS = {
    left   = {'left', 'a'},
    right  = {'right', 'd'},
    jump   = {'up', 'w', 'space', 'z'},
    shrink = {'q'},
    grow   = {'e'},
}

-- keyboard OR touch buttons
function isInputDown(action)
    return love.keyboard.isDown(unpack(INPUT_KEYS[action])) or TouchControls.isDown(action)
end

function wasInputPressed(action)
    local keys = INPUT_KEYS[action]
    for i = 1, #keys do
        if love.keyboard.keysPressed[keys[i]] then return true end
    end
    return TouchControls.wasPressed(action)
end

-- true once the screen has been touched: show touch hints instead of keys
function isTouchUI()
    return TouchControls.visible
end

-- running in a browser (love.js)?
IS_WEB = love.system.getOS() == 'Web'

-- phones, tablets and browsers can't (or shouldn't) quit from a menu
function canQuit()
    local os = love.system.getOS()
    return os ~= 'Web' and os ~= 'Android' and os ~= 'iOS'
end

function love.update(dt)
    dt = mmin(dt, 1 / 30)   -- avoid huge steps after a lag spike
    Timer.update(dt)

    -- the buttons only work while the current screen wants them (playing)
    local cur = gStateMachine.current
    TouchControls.gameplay = cur.wantsTouchControls ~= nil and cur:wantsTouchControls()
    TouchControls.update()

    gStateMachine:update(dt)
    love.keyboard.keysPressed = {}
    TouchControls.endFrame()
end

function love.draw()
    Screen.beginGame()
    gStateMachine:render()
    Screen.endGame()
end
