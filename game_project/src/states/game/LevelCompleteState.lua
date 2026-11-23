--[[
    Inflate - LevelCompleteState
    Shown after touching the goal flag: gems collected and time taken
    (progress is already saved by PlayState).
    Enter = next level (or the ending after the last one). Esc = level select.

    params = { level, gems, totalGems, time, newBestGems, newBestTime }
]]

LevelCompleteState = Class{__includes = BaseState}

local lg = love.graphics

function LevelCompleteState:enter(params)
    self.level = params.level
    self.gems = params.gems
    self.totalGems = params.totalGems
    self.seconds = params.time
    self.newBestGems = params.newBestGems
    self.newBestTime = params.newBestTime
    self.time = 0
    self.isLast = self.level >= LEVEL_COUNT
end

function LevelCompleteState:update(dt)
    self.time = self.time + dt
    local kp = love.keyboard.wasPressed

    -- taps: the bottom line goes to the level select, anywhere else = next
    local toSelect = false
    local gx, gy = TouchControls.consumeTap()
    if gx then
        local py = 36
        toSelect = gy >= py + 85 and gy < py + 98
    end

    if (gx and not toSelect) or kp('return') or kp('kpenter') or kp('space') then
        gSounds['select']:play()
        if self.isLast then
            gStateMachine:change('game-complete')
        else
            gStateMachine:change('play', { level = self.level + 1 })
        end
    elseif toSelect or kp('escape') then
        gStateMachine:change('level-select', { selected = math.min(self.level + 1, LEVEL_COUNT) })
    end
end

function LevelCompleteState:render()
    Background.render(self.time * 10, self.time)
    Screen.beginUI()

    -- panel
    local pw, ph = 180, 100
    local px, py = (BASE_WIDTH - pw) / 2, 36
    Palette.set('K')
    lg.rectangle('fill', px - 1, py - 1, pw + 2, ph + 2)
    Palette.set('D')
    lg.rectangle('fill', px, py, pw, ph)
    Palette.set('d')
    lg.rectangle('fill', px, py, pw, 1)

    PixelFont.print('LEVEL ' .. self.level .. ' COMPLETE!', px, py + 10,
        {align = 'center', width = pw, color = 'Y', shadow = 'r'})

    local mins = math.floor(self.seconds / 60)
    local secs = math.floor(self.seconds % 60)
    local timeText = string.format('%d:%02d', mins, secs)

    SpriteBuilder.draw('gem', 1, px + 44, py + 31)
    PixelFont.print('GEMS  ' .. self.gems .. '/' .. self.totalGems, px + 56, py + 32)
    PixelFont.print('TIME  ' .. timeText, px + 56, py + 46)

    -- "best" badges
    local blink = math.floor(self.time * 4) % 2 == 0
    if self.newBestGems and self.gems > 0 and blink then
        PixelFont.print('BEST!', px + 136, py + 32, {color = 'L'})
    end
    if self.newBestTime and blink then
        PixelFont.print('BEST!', px + 136, py + 46, {color = 'L'})
    end

    if self.gems == self.totalGems and self.totalGems > 0 then
        PixelFont.print('ALL GEMS!', px, py + 62, {align = 'center', width = pw, color = 'L'})
    end

    if math.floor(self.time * 2) % 2 == 0 then
        local key = isTouchUI() and 'TAP' or 'ENTER'
        local prompt = key .. (self.isLast and ': FINISH' or ': NEXT LEVEL')
        PixelFont.print(prompt, px, py + 78, {align = 'center', width = pw, color = 'W'})
    end
    PixelFont.print(isTouchUI() and '< LEVEL SELECT' or 'ESC: LEVEL SELECT', px, py + 88,
        {align = 'center', width = pw, color = 'g'})
    lg.setColor(1, 1, 1, 1)
    Screen.endUI()
end
