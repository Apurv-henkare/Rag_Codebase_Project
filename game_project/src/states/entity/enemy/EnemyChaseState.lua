--[[
    Inflate - EnemyChaseState (shade)
    Chases the ball along the floor, a little slower than the ball's top
    speed. It can't jump: walls, gaps, ledges and 1-tile tunnels stop it, and
    it never walks up to a checkpoint. It gives up (and walks home) when the
    ball gets SHADE_GIVEUP_DIST away or it has been stuck for a while.

    params = { roar = true }   just woke up: roars first, then runs
]]

EnemyChaseState = Class{__includes = BaseState}

local mabs, mmin, mmax = math.abs, math.min, math.max

function EnemyChaseState:init(enemy)
    self.enemy = enemy
    self.roar = 0
    self.stuck = 0
end

function EnemyChaseState:enter(params)
    local e = self.enemy
    e.awake = true
    if params and params.roar then
        self.roar = SHADE_ROAR_TIME
        e.frame = 4
        local ball = e.target
        if ball then e.direction = (ball:centerX() < e:centerX()) and -1 or 1 end
        gSounds['roar']:stop(); gSounds['roar']:play()
        if e.level then e.level:shake(SHAKE_SMALL) end
    end
end

function EnemyChaseState:update(dt)
    local e = self.enemy
    local ball = e.target
    if not ball or ball.dead then
        e:goHome()
        return
    end
    e:applyGravity(dt)

    if self.roar > 0 then
        self.roar = self.roar - dt
        e.frame = 4
        return
    end
    if e.hitPause > 0 then
        e.hitPause = e.hitPause - dt
        e.dx = 0
        e.frame = 2
        return
    end

    local dx = ball:centerX() - e:centerX()
    local dy = ball:centerY() - e:centerY()
    if mabs(dx) > SHADE_GIVEUP_DIST or mabs(dy) > SHADE_GIVEUP_DIST * 0.6 then
        e:changeState('return')
        return
    end

    local want = 0
    if dx > 6 then want = 1 elseif dx < -6 then want = -1 end
    if want ~= 0 then e.direction = want end

    local target = want * SHADE_SPEED
    if e.dx < target then e.dx = mmin(target, e.dx + SHADE_ACCEL * dt)
    else e.dx = mmax(target, e.dx - SHADE_ACCEL * dt) end

    local moved = e:walk(dt)
    if want ~= 0 and not moved then self.stuck = self.stuck + dt else self.stuck = 0 end
    if self.stuck >= SHADE_STUCK_TIME then
        e:changeState('return')
        return
    end

    e.animation:update(dt * (0.4 + mabs(e.dx) / SHADE_SPEED))
    e.frame = (mabs(e.dx) > 1) and e.animation:getCurrentFrame() or 2
end
