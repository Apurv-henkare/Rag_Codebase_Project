--[[
    Inflate - EnemyHopState (frog)
    Sits for a moment, crouches (the warning), then hops. It hops toward the
    ball when it can see it, otherwise keeps going the way it faces. Before
    hopping it checks there is ground to land on; if not, it turns around.
    Hitting a wall in the air turns it around too.
]]

EnemyHopState = Class{__includes = BaseState}

local mabs, mrandom = math.abs, math.random

local function sitTime()
    return FROG_SIT_TIME[1] + mrandom() * (FROG_SIT_TIME[2] - FROG_SIT_TIME[1])
end

function EnemyHopState:init(enemy)
    self.enemy = enemy
    self.phase = 'sit'
    self.timer = sitTime()
end

function EnemyHopState:enter()
    local e = self.enemy
    e.harmless = false
    e.dx = 0
    self.phase = 'sit'
    self.timer = sitTime()
    e.frame = 1
end

-- is there ground where a hop this way would land (within 3 tiles down)?
local HOP_DIST = 42
local function canLand(e, dir)
    local tm = e.tileMap
    local x = e:centerX() + dir * HOP_DIST
    if x < 0 or x > tm.width then return false end
    for dy = 1, 48, 8 do
        if tm:isSolidAt(x, e:bottom() + dy) then return true end
    end
    return false
end

function EnemyHopState:update(dt)
    local e = self.enemy
    local tm = e.tileMap

    if self.phase == 'air' then
        local newX, wall = tm:sweepX(e.x, e.y, e.width, e.height, e.dx * dt)
        if wall or newX < 0 or newX > tm.width - e.width then
            e.dx = 0
            e.direction = -e.direction
        else
            e.x = newX
        end
        e:applyGravity(dt)
        e.frame = 3
        if e.grounded then
            self.phase = 'sit'
            self.timer = sitTime()
            e.dx = 0
            e.frame = 1
        end
        return
    end

    e:applyGravity(dt)
    self.timer = self.timer - dt

    -- turn to face the ball when it is near and in sight
    local ball = e.target
    if ball and not ball.dead and mabs(ball:centerX() - e:centerX()) < FROG_SIGHT
        and mabs(ball:centerY() - e:centerY()) < 64 and e:canSee(ball, FROG_SIGHT + 40) then
        e.direction = (ball:centerX() < e:centerX()) and -1 or 1
    end

    if self.phase == 'sit' then
        e.frame = 1
        if self.timer <= 0 and e.grounded then
            if not canLand(e, e.direction) then
                e.direction = -e.direction
                if not canLand(e, e.direction) then
                    self.timer = 0.6            -- nowhere to go: wait
                    return
                end
            end
            self.phase = 'crouch'
            self.timer = FROG_CROUCH_TIME
        end
    elseif self.phase == 'crouch' then
        e.frame = 2
        if self.timer <= 0 then
            self.phase = 'air'
            e.dy = -FROG_JUMP_SPEED
            e.dx = e.direction * FROG_HOP_SPEED
            e.grounded = false
            if e:nearBall(200) then gSounds['croak']:stop(); gSounds['croak']:play() end
        end
    end
end
