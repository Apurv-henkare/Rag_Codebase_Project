--[[
    Inflate - EnemyStunnedState (crawler, and the jungle's frog / snake / monkey)
    Knocked over by the Big ball: flips upside down, slides, and is harmless
    for STUN_TIME seconds. The Big ball can still squash it. Then it gets up.

    params = { dir = -1 | 1 }  direction it was pushed
]]

EnemyStunnedState = Class{__includes = BaseState}

local mmax, mmin = math.max, math.min

function EnemyStunnedState:init(enemy)
    self.enemy = enemy
    self.timer = 0
end

function EnemyStunnedState:enter(params)
    local e = self.enemy
    local dir = (params and params.dir) or 1
    e.harmless = true
    e.dx = dir * 80
    e.dy = -120
    e.frame = e.stunFrame
end

function EnemyStunnedState:update(dt)
    local e = self.enemy
    local tm = e.tileMap

    -- slide to a stop
    if e.dx > 0 then e.dx = mmax(0, e.dx - 200 * dt)
    elseif e.dx < 0 then e.dx = mmin(0, e.dx + 200 * dt) end
    local newX, wall = tm:sweepX(e.x, e.y, e.width, e.height, e.dx * dt)
    if newX < 0 or newX > tm.width - e.width then wall = true
    else e.x = newX end
    if wall then e.dx = 0 end

    e:applyGravity(dt)

    self.timer = self.timer + dt
    if self.timer >= STUN_TIME and e.grounded then
        e:changeState(e.wakeState)
    end
end
