--[[
    Inflate - EnemySleepState (shade)
    Asleep at its spot, eyes closed. Wakes up (with a roar) when the ball
    comes within SHADE_WAKE_DIST and nothing solid is in between.
]]

EnemySleepState = Class{__includes = BaseState}

function EnemySleepState:init(enemy)
    self.enemy = enemy
end

function EnemySleepState:enter()
    local e = self.enemy
    e.harmless = false
    e.awake = false
    e.dx = 0
    e.hitPause = 0
    e.frame = 1
end

function EnemySleepState:update(dt)
    local e = self.enemy
    e:applyGravity(dt)
    e.frame = 1
    if e:canSee(e.target, SHADE_WAKE_DIST) then
        e:changeState('chase', { roar = true })
    end
end
