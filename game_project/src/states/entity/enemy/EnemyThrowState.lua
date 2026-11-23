--[[
    Inflate - EnemyThrowState (monkey)
    Sits in its spot (blinking now and then). When the ball is in range and
    in sight it holds a coconut up (the warning), then throws it in an arc
    at where the ball is heading. Rests a moment between throws.
]]

EnemyThrowState = Class{__includes = BaseState}

local mabs, mrandom = math.abs, math.random

function EnemyThrowState:init(enemy)
    self.enemy = enemy
end

function EnemyThrowState:enter()
    local e = self.enemy
    e.harmless = false
    e.dx = 0
    self.cool = MONKEY_COOLDOWN * 0.5
    self.windup = 0
    self.blink = 1 + mrandom() * 2
    e.frame = 1
end

-- throws a coconut at the ball, timed to arrive in COCONUT_FLIGHT seconds
local function throw(e, ball)
    local sx, sy = e:centerX() + e.direction * 4 - 3, e.y - 4
    local tx = ball:centerX() + ball.dx * 0.3 - 3
    local ty = ball:centerY() - 3
    local t = COCONUT_FLIGHT
    local vx = math.max(-220, math.min(220, (tx - sx) / t))
    local vy = (ty - sy) / t - 0.5 * COCONUT_GRAVITY * t
    if e.level then e.level:throwCoconut(sx, sy, vx, vy) end
    gSounds['throw']:stop(); gSounds['throw']:play()
end

function EnemyThrowState:update(dt)
    local e = self.enemy
    local ball = e.target
    e:applyGravity(dt)

    local inRange = ball and not ball.dead
        and mabs(ball:centerX() - e:centerX()) < MONKEY_RANGE
        and mabs(ball:centerY() - e:centerY()) < 130
    if inRange then e.direction = (ball:centerX() < e:centerX()) and -1 or 1 end

    if self.windup > 0 then
        e.frame = 3
        self.windup = self.windup - dt
        if self.windup <= 0 then
            if ball and not ball.dead then throw(e, ball) end
            self.cool = MONKEY_COOLDOWN
        end
        return
    end

    -- sitting: blink now and then
    self.blink = self.blink - dt
    if self.blink <= 0 then self.blink = 1.5 + mrandom() * 2 end
    e.frame = (self.blink < 0.15) and 2 or 1

    self.cool = self.cool - dt
    if self.cool <= 0 and inRange and e:canSee(ball, MONKEY_RANGE + 80) then
        self.windup = MONKEY_WINDUP
        e.frame = 3
    end
end
