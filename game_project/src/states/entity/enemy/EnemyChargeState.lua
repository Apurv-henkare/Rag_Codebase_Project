--[[
    Inflate - EnemyChargeState (crystal beetle)
    The beetle saw the ball on its floor: it turns to it, shakes for a moment
    (the warning), then dashes. Hitting a wall leaves it dazed (stunned:
    flipped over and harmless for a moment). It stops at ledges, and gives up
    after BEETLE_CHARGE_TIME.
]]

EnemyChargeState = Class{__includes = BaseState}

local mfloor = math.floor

function EnemyChargeState:init(enemy)
    self.enemy = enemy
    self.timer = 0
    self.windup = true
end

function EnemyChargeState:enter()
    local e = self.enemy
    e.harmless = false
    local ball = e.target
    if ball then e.direction = (ball:centerX() < e:centerX()) and -1 or 1 end
    e.dx = 0
    e.frame = 5
    gSounds['charge']:stop(); gSounds['charge']:play()
end

function EnemyChargeState:exit()
    self.enemy.shakeX = 0
end

-- back to walking, with a short rest before it may charge again
local function calmDown(e)
    e.chargeCooldown = BEETLE_COOLDOWN
    e:changeState('patrol')
end

function EnemyChargeState:update(dt)
    local e = self.enemy
    local tm = e.tileMap
    self.timer = self.timer + dt

    -- warning: shake in place
    if self.windup then
        e.shakeX = (mfloor(self.timer * 30) % 2 == 0) and 1 or -1
        e.frame = 5
        e:applyGravity(dt)
        if self.timer >= BEETLE_WINDUP then
            self.windup = false
            self.timer = 0
            e.shakeX = 0
        end
        return
    end

    -- dash
    e.dx = e.direction * BEETLE_CHARGE_SPEED
    local newX, wall = tm:sweepX(e.x, e.y, e.width, e.height, e.dx * dt)
    if wall or newX < 0 or newX > tm.width - e.width then
        -- slammed into a wall: dazed
        e.x = math.max(0, math.min(newX, tm.width - e.width))
        e.chargeCooldown = BEETLE_COOLDOWN
        gSounds['plate']:stop(); gSounds['plate']:play()
        e:changeState('stunned', { dir = -e.direction })
        return
    end
    local frontX = e.direction > 0 and (newX + e.width + 1) or (newX - 1)
    if e.grounded and not tm:isSolidAt(frontX, e.y + e.height + 1) then
        calmDown(e)                       -- ledge: skid to a stop
        return
    end
    e.x = newX
    e:applyGravity(dt)

    e.animation:update(dt * 3)            -- little legs going fast
    e.frame = e.animation:getCurrentFrame()

    if self.timer >= BEETLE_CHARGE_TIME then calmDown(e) end
end
