--[[
    Inflate - EnemyFlyState (buzzer)
    Hovers in place, bobbing up and down, and turns to face the ball.
    Ignores gravity and tiles.
]]

EnemyFlyState = Class{__includes = BaseState}

local msin, mpi, mrandom = math.sin, math.pi, math.random

function EnemyFlyState:init(enemy)
    self.enemy = enemy
    self.baseY = enemy.y - BUZZER_RANGE / 2   -- bob around a point a bit above its cell
    self.t = mrandom() * BUZZER_PERIOD        -- random phase so buzzers don't sync
end

function EnemyFlyState:enter()
    self.enemy.harmless = false
end

function EnemyFlyState:update(dt)
    local e = self.enemy
    self.t = self.t + dt
    e.y = self.baseY + msin(self.t / BUZZER_PERIOD * 2 * mpi) * BUZZER_RANGE

    local ball = e.target
    if ball then
        e.direction = (ball:centerX() < e:centerX()) and -1 or 1
    end

    e.animation:update(dt)
    e.frame = e.animation:getCurrentFrame()
end
