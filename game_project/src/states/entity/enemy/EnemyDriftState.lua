--[[
    Inflate - EnemyDriftState (jungle beetle)
    Flies left and right around its spot in a gentle wave. When it sees the
    ball close by it turns red-eyed and dives at it ('swoop'), then flies back
    to where it started the dive and drifts on.
]]

EnemyDriftState = Class{__includes = BaseState}

local msin, mabs, mmin, mrandom = math.sin, math.abs, math.min, math.random

function EnemyDriftState:init(enemy)
    self.enemy = enemy
    self.t = mrandom() * 6
end

function EnemyDriftState:enter()
    self.enemy.harmless = false
end

function EnemyDriftState:update(dt)
    local e = self.enemy
    local tm = e.tileMap
    self.t = self.t + dt
    if e.swoopCooldown > 0 then e.swoopCooldown = e.swoopCooldown - dt end

    -- drift sideways, turning at the ends of its range and at walls
    local newX = e.x + e.direction * BUG_SPEED * dt
    local frontX = (e.direction > 0) and (newX + e.width + 2) or (newX - 2)
    if mabs(newX - e.driftX) > BUG_RANGE or tm:isSolidAt(frontX, e:centerY())
        or newX < 0 or newX > tm.width - e.width then
        e.direction = -e.direction
    else
        e.x = newX
    end
    -- bob up and down (eases back to its height after a dive)
    local wantY = e.driftY + msin(self.t * 2.6) * 5
    e.y = e.y + (wantY - e.y) * mmin(1, 4 * dt)

    e.animation:update(dt)
    e.frame = e.animation:getCurrentFrame()

    local ball = e.target
    if e.swoopCooldown <= 0 and e:canSee(ball, BUG_SIGHT) then
        e.direction = (ball:centerX() < e:centerX()) and -1 or 1
        e.frame = 4
        e.homeX, e.homeY = e.x, e.y
        local tx, ty = ball:centerX() + ball.dx * 0.25, ball:centerY()
        if tm:isSolidAt(tx, ty) then tx = ball:centerX() end
        e:changeState('swoop', { x = tx, y = ty })
    end
end
