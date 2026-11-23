--[[
    Inflate - PauseState
    An overlay that lives inside PlayState (not a StateMachine state), so the
    level stays exactly as it was underneath while paused.
    Esc / P resumes.
]]

PauseState = Class{}

local lg = love.graphics

function PauseState:init(playState)
    self.playState = playState
    local levelNumber = playState.levelNumber
    self.menu = Menu{ items = {
        { text = 'RESUME', onSelect = function() playState:resume() end },
        { text = 'RESTART', onSelect = function()
            gStateMachine:change('play', { level = levelNumber })
        end },
        { text = 'LEVEL SELECT', onSelect = function()
            gStateMachine:change('level-select', { selected = levelNumber })
        end },
        { text = 'QUIT TO TITLE', onSelect = function()
            gStateMachine:change('start')
        end },
    }}
end

function PauseState:update(dt)
    if love.keyboard.wasPressed('escape') or love.keyboard.wasPressed('p') then
        self.playState:resume()
        return
    end
    self.menu:update()
end

function PauseState:render()
    -- dim the frozen level
    Palette.set('K', 0.6)
    lg.rectangle('fill', 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)

    Screen.beginUI()
    local pw, ph = 140, 74
    local px, py = (BASE_WIDTH - pw) / 2, 50
    Palette.set('K')
    lg.rectangle('fill', px - 1, py - 1, pw + 2, ph + 2)
    Palette.set('D')
    lg.rectangle('fill', px, py, pw, ph)
    Palette.set('d')
    lg.rectangle('fill', px, py, pw, 1)

    PixelFont.print('PAUSED', px, py + 8, {align = 'center', width = pw, color = 'Y', shadow = 'r'})
    self.menu:render(px, py + 24, pw)
    lg.setColor(1, 1, 1, 1)
    Screen.endUI()
end
