--[[
    Inflate - EnemySquashedState
    Flattened by the Big ball: shows the squashed frame briefly, then is removed.
    (The burst of particles is made by GameLevel when the squash happens.)
]]

EnemySquashedState = Class{__includes = BaseState}

function EnemySquashedState:init(enemy)
    self.enemy = enemy
    self.timer = 0
end

function EnemySquashedState:enter()
    local e = self.enemy
    e.harmless = true
    e.squashed = true
    e.dx, e.dy = 0, 0
    e.frame = e.squashFrame
end

function EnemySquashedState:update(dt)
    self.timer = self.timer + dt
    if self.timer >= 0.45 then
        self.enemy.remove = true
    end
end
