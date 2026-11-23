--[[
    Inflate - BallGroundState
    Rolling on the ground. Jump to go airborne; rolling off an edge falls.
]]

BallGroundState = Class{__includes = BaseState}

function BallGroundState:init(ball)
    self.ball = ball
end

function BallGroundState:enter()
    local b = self.ball
    b.dy = 0
    b.jumping = false
    b.grounded = true
    b.coyote = COYOTE_TIME
end

function BallGroundState:exit()
    self.ball.grounded = false
end

function BallGroundState:update(dt)
    local b = self.ball
    local s = b:getSize()

    b:horizontalInput(dt, s.accel, GROUND_FRICTION)
    if b.inWater then b:limitWaterSpeed() end

    if b.jumpBuffer > 0 then
        if b.inWater and s.waterSpeed > 0 then
            b.jumpBuffer = 0       -- Big can't jump under water, only roll
        else
            b:jump()
            return
        end
    end

    -- Small / Normal under water float up off the floor
    if b.inWater and s.waterSpeed < 0 and b:centerY() > b.surfaceY + 1 then
        b:changeState('air')
        return
    end

    -- standing on / rolling over a vent that is strong enough: lifted off
    if b.floatBottom and b.floatBottom < b:bottom() - 2 then
        b:changeState('air')
        return
    end

    b:moveX(dt)

    -- rolled off an edge (or the tile below was removed)
    if not b:onGround() then
        b.coyote = COYOTE_TIME
        b:changeState('air')
    end
end
