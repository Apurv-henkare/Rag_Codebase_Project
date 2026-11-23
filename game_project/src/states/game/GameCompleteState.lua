--[[
    Inflate - GameCompleteState
    Shown after finishing the last level. Enter = back to the title.
]]

GameCompleteState = Class{__includes = BaseState}

local lg = love.graphics
local mfloor = math.floor

function GameCompleteState:enter()
    self.time = 0
    self.logo = PixelFont.makeLogo('WELL DONE!', 3, {'W', 'L', 'G', 'K', 'T'})

    self.bestGems = SaveData.totalBestGems()
    self.allGems = 0
    for n = 1, LEVEL_COUNT do
        self.allGems = self.allGems + LevelMaker.info(n).gems
    end

    self.particles = Particles(120)
    self.burstTimer = 0
end

function GameCompleteState:update(dt)
    self.time = self.time + dt

    -- confetti bursts every so often
    self.burstTimer = self.burstTimer - dt
    if self.burstTimer <= 0 then
        self.burstTimer = 0.6
        self.particles:emit(math.random(40, VIRTUAL_WIDTH - 40), math.random(60, 120), 14, {
            colors = {'Y', 'O', 'W', 'L', 'C'}, speed = {40, 110}, upward = true,
            gravity = 160, life = {0.8, 1.4}, size = {1, 2},
        })
    end
    self.particles:update(dt)

    local kp = love.keyboard.wasPressed
    if TouchControls.consumeTap() or kp('return') or kp('kpenter') or kp('space') or kp('escape') then
        gSounds['select']:play()
        gStateMachine:change('start')
    end
end

function GameCompleteState:render()
    Background.render(self.time * 15, self.time)
    self.particles:render()

    Screen.beginUI()
    lg.setColor(1, 1, 1, 1)
    lg.draw(self.logo, mfloor((BASE_WIDTH - self.logo:getWidth()) / 2), 22)

    PixelFont.print('YOU FINISHED ALL ' .. LEVEL_COUNT .. ' LEVELS', 0, 64,
        {align = 'center', color = 'W', outline = 'K'})

    local text = 'GEMS  ' .. self.bestGems .. '/' .. self.allGems
    local tw = PixelFont.width(text)
    local x = mfloor((BASE_WIDTH - tw - 10) / 2)
    SpriteBuilder.draw('gem', 1, x, 79)
    PixelFont.print(text, x + 10, 80, {color = 'Y', outline = 'K'})

    PixelFont.print('THANKS FOR PLAYING!', 0, 100, {align = 'center', color = 'L', outline = 'K'})

    if mfloor(self.time * 2) % 2 == 0 then
        PixelFont.print(isTouchUI() and 'TAP TO CONTINUE' or 'PRESS ENTER', 0, 124, {align = 'center', color = 'W', outline = 'K'})
    end
    Screen.endUI()
end
