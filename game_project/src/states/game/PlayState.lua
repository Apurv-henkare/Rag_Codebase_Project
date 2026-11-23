--[[
    Inflate - PlayState
    Runs a level: the ball, interactions, camera, HUD, pause menu.
    Popping respawns the ball at the last checkpoint (or the start); gems,
    keys and broken blocks stay as they are. Touching the flag saves progress
    and goes to the win screen.

    params = { level = n }   (defaults to level 1)
]]

PlayState = Class{__includes = BaseState}

local mexp = math.exp

function PlayState:enter(params)
    self.levelNumber = (params and params.level) or 1
    self.level = LevelMaker.load(self.levelNumber)
    self.camera = Camera(self.level.width, self.level.height)
    self.time = 0
    self.goalTimer = 0
    self.freezeTimer = 0
    self.paused = false
    self.pauseMenu = nil

    self.level.onShake = function(amount, duration) self.camera:shake(amount, duration) end
    self.level.onFreeze = function(seconds) self.freezeTimer = math.max(self.freezeTimer, seconds) end

    self.ball = Ball(self.level, self.level.spawnX, self.level.spawnY)
    self.ball.onPop = function()
        local level = self.level
        self.ball:respawnAt(level.checkpointX, level.checkpointY)
        self.lookahead = 0
        self.camera:snapTo(self.ball:centerX(), self.ball:centerY())
    end

    self.lookahead = 0
    self.camera:snapTo(self.ball:centerX(), self.ball:centerY())
end

-- touch buttons are shown while actually playing
function PlayState:wantsTouchControls()
    return not self.paused and not self.level.completed
end

function PlayState:pause()
    self.paused = true
    self.pauseMenu = PauseState(self)
    gSounds['select']:stop(); gSounds['select']:play()
end

function PlayState:resume()
    self.paused = false
    self.pauseMenu = nil
end

function PlayState:update(dt)
    if self.paused then
        self.pauseMenu:update(dt)
        return
    end

    -- web on a phone: turning it upright shows a "rotate your phone" screen
    -- over the game (web/play.html), so pause underneath. Only on the moment
    -- it turns, so the player can still resume if they want to.
    local turnedUpright = IS_WEB and Screen.portrait and not self.wasPortrait
    self.wasPortrait = Screen.portrait

    if love.keyboard.wasPressed('escape') or love.keyboard.wasPressed('p')
        or TouchControls.wasPressed('pause') or turnedUpright then
        self:pause()
        return
    end

    -- hit freeze: everything holds still for a split second
    if self.freezeTimer > 0 then
        self.freezeTimer = self.freezeTimer - dt
        return
    end

    self.time = self.time + dt
    self.camera:updateShake(dt)

    -- level finished: let the celebration play, then save and show the win screen
    if self.level.completed then
        self.level:update(dt, self.ball)
        self.goalTimer = self.goalTimer + dt
        if self.goalTimer >= GOAL_DELAY then
            local gems = self.level.gemsCollected
            local newBestGems, newBestTime = SaveData.recordLevel(self.levelNumber, gems, self.time)
            gStateMachine:change('level-complete', {
                level = self.levelNumber,
                gems = gems,
                totalGems = self.level.totalGems,
                time = self.time,
                newBestGems = newBestGems,
                newBestTime = newBestTime,
            })
        end
        return
    end

    self.ball:update(dt)
    self.level:update(dt, self.ball)
    self.level:checkBall(self.ball)

    -- camera looks a little ahead in the direction the ball is rolling
    if not self.ball.dead then
        local target = clamp(self.ball.dx * CAMERA_LOOKAHEAD, -CAMERA_LOOKAHEAD_MAX, CAMERA_LOOKAHEAD_MAX)
        self.lookahead = self.lookahead + (target - self.lookahead) * (1 - mexp(-CAMERA_LOOKAHEAD_SPEED * dt))
        self.camera:follow(self.ball:centerX() + self.lookahead, self.ball:centerY(), dt)
    end
end

function PlayState:render()
    local camX, camY = self.camera:getPosition()

    Background.render(camX, self.time, camY, self.level.height, self.level.theme)

    self.camera:attach()
    self.level:render(camX, camY)
    self.ball:render()
    self.level:renderWater(camX, camY)     -- see-through water over everything in it
    self.level:renderWaterfalls(camX, camY)
    self.level:renderEffects()
    self.camera:detach()

    HUD.render(self.ball, self.level, self.time)

    -- level name + controls for the first few seconds
    if self.time < CONTROLS_HINT_TIME then
        PixelFont.print('LEVEL ' .. self.levelNumber .. ': ' .. self.level.name, 0, 24,
            {align = 'center', color = 'Y', outline = 'K'})
        if not isTouchUI() then
            PixelFont.print('<- ->: ROLL  SPACE: JUMP  Q/E: SIZE  ESC: PAUSE', 0, VIRTUAL_HEIGHT - 11,
                {align = 'center', color = 'g', outline = 'K'})
        end
    end

    -- short messages: CHECKPOINT!, GOT THE KEY!, FIND THE KEY!, UNLOCKED!
    if self.level.message then
        PixelFont.print(self.level.message, 0, 36, {align = 'center', color = 'W', outline = 'K'})
    end

    if self.paused then
        self.pauseMenu:render()
    end
end
