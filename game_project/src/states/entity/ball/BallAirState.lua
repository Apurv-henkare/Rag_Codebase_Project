--[[
    Inflate - BallAirState
    Jumping, falling and bouncing. Gravity pulls the ball down; landing either
    bounces it back up (fast impact) or settles it on the ground.
]]

BallAirState = Class{__includes = BaseState}

local mmin = math.min

function BallAirState:init(ball)
    self.ball = ball
    self.jumpCut = false
end

function BallAirState:enter()
    self.ball.grounded = false
end

function BallAirState:update(dt)
    local b = self.ball
    local s = b:getSize()

    b:horizontalInput(dt, s.accel * AIR_CONTROL, AIR_FRICTION)
    if b.inWater then b:limitWaterSpeed() end

    -- floating at the surface (Small / Normal): jump out of the water
    if b.inWater and b.jumpBuffer > 0 and s.waterSpeed < 0 and b:centerY() <= b.surfaceY + 6 then
        b:jump()
        return
    end

    -- late jump just after leaving the ground or bouncing (coyote time).
    -- Not in water: there only the surface jump above works.
    if b.jumpBuffer > 0 and b.coyote > 0 and not b.inWater then
        b:jump()
        return
    end
    b.coyote = b.coyote - dt

    -- let go of jump early = shorter jump (but never shorter than a small hop)
    b.jumpTime = (b.jumpTime or 0) + dt
    if b.jumping and not self.jumpCut and b.dy * b.grav < 0 and b.jumpTime >= JUMP_MIN_TIME
        and not isInputDown('jump') then
        b.dy = b.dy * JUMP_CUT
        self.jumpCut = true
    end
    if b.dy * b.grav >= 0 then b.jumping = false end

    if b.inWater and not (b.jumping and b.dy < 0) then
        b:applyWater(dt)           -- floating up / sinking (a jump out carries on)
    elseif b.floatBottom then
        b:applyFloat(dt)           -- riding a vent's air instead of falling
    elseif b.grav < 0 then
        -- upside down: "falling" up (the Small ball a little slower)
        local g = s.gravity * ((b.sizeIndex == 1) and FLIP_SMALL_GRAVITY or 1)
        b.dy = math.max(b.dy - GRAVITY * g * dt, -MAX_FALL_SPEED)
    else
        b.dy = mmin(b.dy + GRAVITY * s.gravity * dt, MAX_FALL_SPEED)
        -- inside a waterfall: pushed down hard (Small) or a little (Big)
        if b.fallPush > 0 then
            b.dy = mmin(b.dy + b.fallPush * dt, MAX_FALL_SPEED)
            b.jumping = b.jumping and b.dy < 0
        end
    end

    b:moveX(dt)
    local result, impact = b:moveY(dt)
    if result == 'land' then
        b:land(impact)
    end
end
