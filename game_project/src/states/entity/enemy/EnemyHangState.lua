--[[
    Inflate - EnemyHangState (cave bat)
    Hangs upside down from the ceiling, asleep. When the ball passes below
    (close sideways, nothing in between) it wakes and swoops.
]]

EnemyHangState = Class{__includes = BaseState}

local mabs = math.abs

function EnemyHangState:init(enemy)
    self.enemy = enemy
end

function EnemyHangState:enter()
    local e = self.enemy
    e.harmless = false
    e.x, e.y = e.homeX, e.homeY
    e.dx, e.dy = 0, 0
    e.frame = 4
end

function EnemyHangState:update(dt)
    local e = self.enemy
    e.frame = 4
    if e.swoopCooldown > 0 then
        e.swoopCooldown = e.swoopCooldown - dt
        return
    end

    local ball = e.target
    if not ball or ball.dead then return end
    local dx = ball:centerX() - e:centerX()
    local dy = ball:centerY() - e.y
    if mabs(dx) <= BAT_SIGHT_X and dy > 0 and dy <= BAT_SIGHT_Y
        and e:canSee(ball, BAT_SIGHT_X + BAT_SIGHT_Y) then
        -- aim a little ahead of a rolling ball
        local tx, ty = ball:centerX() + ball.dx * BAT_LEAD, ball:centerY()
        if e.tileMap:isSolidAt(tx, ty) then tx = ball:centerX() end
        e:changeState('swoop', { x = tx, y = ty })
    end
end
