--[[
    Inflate - EnemyReturnState (shade)
    The ball got away: walk slowly back home and fall asleep there. If the
    ball comes close again on the way, chase again (no roar this time).
]]

EnemyReturnState = Class{__includes = BaseState}

local mabs = math.abs

function EnemyReturnState:init(enemy)
    self.enemy = enemy
    self.stuck = 0
end

function EnemyReturnState:enter()
    self.enemy.awake = true
end

function EnemyReturnState:update(dt)
    local e = self.enemy
    local ball = e.target
    if not ball or ball.dead then
        e:goHome()
        return
    end
    e:applyGravity(dt)

    if e:canSee(ball, SHADE_WAKE_DIST) then
        e:changeState('chase')
        return
    end

    local dx = e.homeX - e.x
    if mabs(dx) <= 1 then
        e.x, e.dx = e.homeX, 0
        e:changeState('sleep')
        return
    end
    e.direction = (dx > 0) and 1 or -1
    e.dx = e.direction * SHADE_RETURN_SPEED
    if mabs(e.dx * dt) > mabs(dx) then e.dx = dx / dt end   -- don't walk past home

    if e:walk(dt) then self.stuck = 0 else self.stuck = self.stuck + dt end
    if self.stuck > 2 then
        e:goHome()                 -- something is in the way: just go back
        return
    end

    e.animation:update(dt * 0.5)
    e.frame = e.animation:getCurrentFrame()
end
