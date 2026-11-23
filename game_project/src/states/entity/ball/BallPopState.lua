--[[
    Inflate - BallPopState
    Out of air (or fell out of the level): the ball bursts into pieces,
    then after a moment ball.onPop() is called (PlayState restarts the level).
]]

BallPopState = Class{__includes = BaseState}

function BallPopState:init(ball)
    self.ball = ball
    self.timer = 0
    self.done = false
end

function BallPopState:enter()
    local b = self.ball
    b.dead = true
    b.dx, b.dy = 0, 0
    b.grounded = false

    gSounds['pop']:stop()
    gSounds['pop']:play()
    b.level:shake(SHAKE_BIG)

    -- rubber pieces + a puff of air
    local cx, cy = b:centerX(), b:centerY()
    b.level.particles:emit(cx, cy, 16, {
        colors = {'R', 'r', 'O'}, speed = {60, 150}, upward = true,
        gravity = 420, life = {0.6, 1.0}, size = {1, 3},
    })
    b.level.particles:emit(cx, cy, 8, {
        colors = {'W', 'C'}, speed = {20, 60}, gravity = -30, life = {0.3, 0.6}, size = {1, 2},
    })
end

function BallPopState:update(dt)
    self.timer = self.timer + dt
    if not self.done and self.timer >= POP_RESTART_TIME then
        self.done = true
        if self.ball.onPop then self.ball.onPop() end
    end
end
