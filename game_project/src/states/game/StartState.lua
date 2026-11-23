--[[
    Inflate - StartState
    Title screen: scrolling background, bouncing ball, logo, main menu.
    F1 opens the art preview (developer screen).
]]

StartState = Class{__includes = BaseState}

local mfloor, mabs = math.floor, math.abs

local GRAVITY_DEMO = 520
local BOUNCE_SPEED = -230
local SQUASH_DEMO = 0.08

function StartState:init()
    self.time = 0
    -- logo: highlight, fill, shade, outline, shadow
    self.logo = PixelFont.makeLogo('INFLATE', 4, {'W', 'Y', 'O', 'K', 'r'})

    -- demo ball bouncing on the left (ballX is in the menu layout; ballY is the
    -- height above the ground row, so it works for any screen height)
    self.ballX = 44
    self.ballY = -60         -- bottom of the ball, relative to the ground
    self.ballDY = 0
    self.squashTimer = 0

    local hasProgress = SaveData.data.unlocked > 1 or SaveData.getRecord(1) ~= nil
    self.menu = Menu{ items = {
        { text = hasProgress and 'CONTINUE' or 'PLAY', onSelect = function()
            gStateMachine:change('play', { level = SaveData.continueLevel() })
        end },
        { text = 'LEVEL SELECT', onSelect = function()
            gStateMachine:change('level-select')
        end },
    }}
    -- no Quit in a browser or on phones
    if canQuit() then
        table.insert(self.menu.items, { text = 'QUIT', onSelect = function()
            love.event.quit()
        end })
    end
end

function StartState:update(dt)
    self.time = self.time + dt

    if love.keyboard.wasPressed('f1') then
        gStateMachine:change('art-preview')
        return
    end
    if love.keyboard.wasPressed('escape') and canQuit() then
        love.event.quit()
        return
    end

    self.menu:update()

    self.ballDY = self.ballDY + GRAVITY_DEMO * dt
    self.ballY = self.ballY + self.ballDY * dt
    if self.ballY >= 0 then
        self.ballY = 0
        self.ballDY = BOUNCE_SPEED
        self.squashTimer = SQUASH_DEMO
    end
    self.squashTimer = math.max(0, self.squashTimer - dt)
end

function StartState:render()
    Background.render(self.time * 20, self.time)

    -- ground row along the bottom of the whole view
    local groundY = VIRTUAL_HEIGHT - TILE_SIZE
    local scroll = mfloor(self.time * 20) % TILE_SIZE
    for x = -scroll, VIRTUAL_WIDTH, TILE_SIZE do
        SpriteBuilder.draw('ground-top', 1, x, groundY)
    end

    -- ball: squash just after landing, stretch while moving fast
    local frame = 1
    if self.squashTimer > 0 then frame = 2
    elseif mabs(self.ballDY) > 150 then frame = 3 end
    local _, _, w, h = gFrames['ball-normal'][frame]:getViewport()
    SpriteBuilder.draw('ball-normal', frame, Screen.uiX + self.ballX - w / 2, groundY + self.ballY - h)

    Screen.beginUI()
    -- logo + subtitle
    love.graphics.draw(self.logo, mfloor((BASE_WIDTH - self.logo:getWidth()) / 2), 16)
    PixelFont.print('A BOUNCING BALL ADVENTURE', 0, 56, {align = 'center', color = 'W', outline = 'K'})

    self.menu:render(0, 84, BASE_WIDTH)
    Screen.endUI()
end
