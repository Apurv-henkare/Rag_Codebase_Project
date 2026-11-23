--[[
    Inflate - EnemySwimState (piranha)
    Can't be hurt. Swims back and forth inside its pool. When the ball is
    above it (on a ledge, jumping over, floating) it leaps out of the water
    at it, then falls back in. Now and then it jumps just to show it's there.
    A piranha that lands on dry ground goes straight back to its pool.

      swim <-> leap
]]

EnemySwimState = Class{__includes = BaseState}

local msin, msqrt, mabs, mmin, mmax, mrandom = math.sin, math.sqrt, math.abs, math.min, math.max, math.random

function EnemySwimState:init(enemy)
    self.enemy = enemy
    self.t = mrandom() * 6
end

function EnemySwimState:enter()
    local e = self.enemy
    self.phase = 'swim'
    self.cool = mrandom() * PIRANHA_COOLDOWN
    self.wait = 0
    e.harmless = false
    e.dx, e.dy = 0, 0
end

-- is this point inside open water?
local function water(tm, x, y)
    return tm:isWaterAt(x, y) and not tm:isSolidAt(x, y)
end

function EnemySwimState:leap(height, toward)
    local e = self.enemy
    height = mmax(32, mmin(150, height))
    e.dy = -msqrt(2 * GRAVITY * height)
    local air = 2 * -e.dy / GRAVITY
    e.dx = mmax(-60, mmin(60, toward / air))
    if e.dx ~= 0 then e.direction = (e.dx < 0) and -1 or 1 end
    self.phase = 'leap'
    if e:nearBall(220) then gSounds['chomp']:stop(); gSounds['chomp']:play() end
    if e.level then
        local tm = e.tileMap
        e.level.particles:emit(e:centerX(), tm:waterSurface(e:centerX(), e:centerY()), 6, {
            colors = {'W', 'C'}, speed = {30, 70}, upward = true,
            gravity = 400, life = {0.25, 0.45}, size = {1, 2},
        })
    end
end

function EnemySwimState:update(dt)
    local e = self.enemy
    local tm = e.tileMap
    self.t = self.t + dt

    if self.phase == 'leap' then
        e.frame = 3
        e.dy = mmin(e.dy + GRAVITY * dt, MAX_FALL_SPEED)
        local newY, hitY = tm:sweepY(e.x, e.y, e.width, e.height, e.dy * dt)
        local falling = e.dy > 0
        e.y = newY
        if hitY then e.dy = 0 end
        local newX, wall = tm:sweepX(e.x, e.y, e.width, e.height, e.dx * dt)
        if wall then e.dx = 0 else e.x = newX end

        if falling and water(tm, e:centerX(), e:centerY()) then
            -- back in the pool
            self.phase = 'swim'
            self.cool = PIRANHA_COOLDOWN
            e.dy, e.dx = 0, 0
        elseif hitY and falling then
            -- landed on dry ground: back home
            e.x, e.y = e.homeX, e.homeY
            self.phase = 'swim'
            self.cool = PIRANHA_COOLDOWN
            e.dy, e.dx = 0, 0
        end
        return
    end

    -- swimming: along the pool, turning where the water ends
    local newX = e.x + e.direction * PIRANHA_SPEED * dt
    local frontX = (e.direction > 0) and (newX + e.width + 1) or (newX - 1)
    if not water(tm, frontX, e:centerY()) or newX < 0 or newX > tm.width - e.width then
        e.direction = -e.direction
    else
        e.x = newX
    end
    -- a gentle bob around its depth (never above the surface)
    local wantY = e.homeY + msin(self.t * 2) * 2
    if water(tm, e:centerX(), wantY + 1) then e.y = wantY end

    e.animation:update(dt)
    e.frame = e.animation:getCurrentFrame()

    self.cool = self.cool - dt
    if self.cool > 0 then return end
    local ball = e.target
    if not ball or ball.dead then return end
    local dx = ball:centerX() - e:centerX()
    local above = e.y - ball:centerY()
    if mabs(dx) < PIRANHA_SIGHT_X and above > 0 and above < PIRANHA_SIGHT_Y
        and e:canSee(ball, PIRANHA_SIGHT_X + PIRANHA_SIGHT_Y) then
        self:leap(above + 10, dx)
    elseif e:nearBall(200) then
        -- jump now and then, just to be seen
        self.wait = self.wait + dt
        if self.wait > 2.5 + mrandom() * 2 then
            self.wait = 0
            self:leap(36, 0)
        end
    end
end
