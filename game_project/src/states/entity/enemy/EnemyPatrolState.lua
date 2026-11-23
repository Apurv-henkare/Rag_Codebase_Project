--[[
    Inflate - EnemyPatrolState (crawler)
    Walks back and forth; turns around at walls, level edges and ledges.
    Smart crawlers (crystal beetles) switch to 'charge' when they see the ball.
]]

EnemyPatrolState = Class{__includes = BaseState}

function EnemyPatrolState:init(enemy)
    self.enemy = enemy
end

function EnemyPatrolState:enter()
    self.enemy.harmless = false
end

function EnemyPatrolState:update(dt)
    local e = self.enemy
    local tm = e.tileMap

    -- crystal beetle: charges when it sees the ball on its floor
    if e.smart then
        if e.chargeCooldown > 0 then
            e.chargeCooldown = e.chargeCooldown - dt
        elseif e.grounded and e:seesOnFloor(e.target) then
            e:changeState('charge')
            return
        end
    end

    e.dx = e.direction * CRAWLER_SPEED
    local newX, wall = tm:sweepX(e.x, e.y, e.width, e.height, e.dx * dt)

    if wall or newX < 0 or newX > tm.width - e.width then
        e.direction = -e.direction
    else
        -- don't walk off ledges: is there ground just ahead of our feet?
        local frontX = e.direction > 0 and (newX + e.width + 1) or (newX - 1)
        if e.grounded and not tm:isSolidAt(frontX, e.y + e.height + 1) then
            e.direction = -e.direction
        else
            e.x = newX
        end
    end

    e:applyGravity(dt)

    e.animation:update(dt)
    e.frame = e.animation:getCurrentFrame()
end
