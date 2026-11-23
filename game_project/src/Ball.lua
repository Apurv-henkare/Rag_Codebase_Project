--[[
    Inflate - Ball (the player)
    A bouncy ball with 3 sizes. Rolls with momentum, bounces on landing,
    jumps, and changes size with Q / E.

    Air is health: spikes and enemies leak it, pumps refill it, growing costs it.
    At 0 air (or falling out of the level) the ball pops.

    States: 'ground' (rolling), 'air' (jumping / falling / bouncing), 'pop'.
    The collision box is a square the size of the ball's diameter.
]]

Ball = Class{__includes = Entity}

local mabs, mmin, mmax, mfloor = math.abs, math.min, math.max, math.floor

-- level: GameLevel. (x, y): bottom-centre spawn point
function Ball:init(level, x, y)
    self.sizeIndex = BALL_START_SIZE
    local d = BALL_SIZES[self.sizeIndex].diameter
    Entity.init(self, { x = x - d / 2, y = y - d, width = d, height = d })

    self.level = level
    self.tileMap = level.tileMap

    self.prevY = self.y
    self.roll = 0             -- spin angle (radians) for the rolling animation
    self.air = AIR_MAX
    self.invuln = 0           -- > 0: flashing, can't be hurt
    self.refillTimer = 0      -- > 0: being pumped up
    self.dead = false
    self.onPop = nil          -- callback set by PlayState, called after the pop animation

    self.squashTimer = 0
    self.jumpBuffer = 0
    self.coyote = 0
    self.jumping = false      -- true while rising from a jump (allows jump cut)
    self.grounded = false

    -- fans: y the ball floats up to inside a vent's air (nil = none) and
    -- the sideways push of blowers (eases in / out)
    self.floatBottom = nil
    self.windX = 0
    self.fallPush = 0         -- extra downward push inside a waterfall (px/s^2)

    -- water: inWater (bottom is in water), submerged (completely under),
    -- surfaceY (y of the water surface above the ball)
    self.inWater = false
    self.submerged = false
    self.surfaceY = 0

    -- gravity: 1 = normal (falls down), -1 = flipped by an orb (falls up,
    -- rolls along ceilings). The states use it for every "down".
    self.grav = 1

    self.stateMachine = StateMachine {
        ['ground'] = function() return BallGroundState(self) end,
        ['air']    = function() return BallAirState(self) end,
        ['pop']    = function() return BallPopState(self) end,
    }
    self:changeState('air')
end

function Ball:getSize()
    return BALL_SIZES[self.sizeIndex]
end

function Ball:update(dt)
    if self.dead then
        Entity.update(self, dt)    -- only the pop state runs
        return
    end

    self.prevY = self.y            -- used to tell a stomp from a side hit
    local startX = self.x

    -- remember a jump press for a moment (jump buffer)
    if wasInputPressed('jump') then
        self.jumpBuffer = JUMP_BUFFER_TIME
    else
        self.jumpBuffer = mmax(0, self.jumpBuffer - dt)
    end

    if wasInputPressed('shrink') then self:changeSize(-1)
    elseif wasInputPressed('grow') then self:changeSize(1) end

    self:updateWater(dt)
    if self.dead then return end   -- ran out of air under water

    -- air from fans (used by the ground / air states and moveX)
    local floatBottom, windX = self.level:airAt(self)
    self.floatBottom = floatBottom
    self.windX = self.windX + (windX - self.windX) * mmin(1, WIND_SMOOTH * dt)
    -- waterfalls push down (used by the air state)
    self.fallPush = self.level:waterfallAt(self)

    Entity.update(self, dt)
    if self.dead then return end   -- popped during this update

    -- spin by the distance actually rolled (stops against walls). Big jumps
    -- (resizing, respawning) are ignored.
    local moved = self.x - startX
    if mabs(moved) < 16 then
        self.roll = (self.roll + moved / (self.width / 2)) % (math.pi * 2)
    end

    self.squashTimer = mmax(0, self.squashTimer - dt)
    self.invuln = mmax(0, self.invuln - dt)

    if self.refillTimer > 0 then
        self.air = mmin(AIR_MAX, self.air + AIR_MAX / PUMP_REFILL_TIME * dt)
        self.refillTimer = self.refillTimer - dt
    end

    -- fell out of the level (below it, or up out of the top when flipped)
    if self.y > self.level.height + FALL_OUT_MARGIN
        or (self.grav < 0 and self.y + self.height < -FALL_OUT_MARGIN) then
        self:pop()
    end
end

---------------------------------------------------------------------------
-- AIR / DAMAGE
---------------------------------------------------------------------------

-- fromX: x position of what hurt us (the ball is pushed away from it)
function Ball:hurt(amount, fromX)
    if self.invuln > 0 or self.dead then return false end

    self.air = self.air - amount
    self.refillTimer = 0
    self.level.particles:emit(self:centerX(), self:centerY(), 6, {
        colors = {'C', 'W'}, speed = {30, 80}, gravity = -40, life = {0.3, 0.6}, size = {1, 2},
    })
    gSounds['leak']:stop(); gSounds['leak']:play()

    if self.air <= 0 then
        self:pop()
        return true
    end

    gSounds['hurt']:stop(); gSounds['hurt']:play()
    self.invuln = HURT_INVULN_TIME
    self.dy = -HURT_BOUNCE_SPEED * self.grav       -- away from the floor (or ceiling)
    self.dx = self.dx + sign(self:centerX() - fromX) * HURT_PUSH_SPEED
    self.jumping = false
    self:changeState('air')
    return true
end

-- start refilling to full. Returns false if already full.
function Ball:refill()
    if self.air >= AIR_MAX or self.dead then return false end
    self.refillTimer = PUMP_REFILL_TIME
    return true
end

function Ball:pop()
    if self.dead then return end
    self.air = 0
    self:changeState('pop')
end

---------------------------------------------------------------------------
-- MOVEMENT HELPERS (used by the states)
---------------------------------------------------------------------------

function Ball:isBig()
    return self.sizeIndex == #BALL_SIZES
end

-- left/right input with acceleration, top speed and friction
function Ball:horizontalInput(dt, accel, friction)
    local s = self:getSize()
    local dir = 0
    if isInputDown('left') then dir = dir - 1 end
    if isInputDown('right') then dir = dir + 1 end

    if dir ~= 0 then
        -- turning around also brakes, so changing direction feels snappy
        if self.dx ~= 0 and sign(self.dx) ~= dir then
            self.dx = self.dx + dir * friction * dt
        end
        self.dx = clamp(self.dx + dir * accel * dt, -s.maxSpeed, s.maxSpeed)
    else
        if self.dx > 0 then self.dx = mmax(0, self.dx - friction * dt)
        elseif self.dx < 0 then self.dx = mmin(0, self.dx + friction * dt) end
    end
end

-- water: works out inWater / submerged / surfaceY, splashes, and air under
-- water (lost slowly, refilled inside bubble streams)
function Ball:updateWater(dt)
    local tm = self.tileMap
    if not tm.hasWater then return end
    local cx = self:centerX()
    local wasIn = self.inWater
    self.inWater = tm:isWaterAt(cx, self:bottom() - 2)
    self.submerged = self.inWater and tm:isWaterAt(cx, self.y + 1)
    if self.inWater then
        self.surfaceY = tm:waterSurface(cx, self:bottom() - 2)
        if not wasIn and self.dy > SPLASH_SPEED then
            self.level:splash(cx, self.surfaceY, self.dy)
        end
    elseif wasIn and self.dy < -SPLASH_SPEED then
        self.level:splash(cx, self.surfaceY, -self.dy)
    end

    if self.submerged then
        if self.level:bubblesAt(self) then
            self.air = mmin(AIR_MAX, self.air + BUBBLE_REFILL * dt)
        else
            self.air = self.air - WATER_AIR_DRAIN * dt
            if self.air <= 0 then self:pop() end
        end
    end
end

-- in water: slower top speed
function Ball:limitWaterSpeed()
    local m = self:getSize().maxSpeed * WATER_MOVE
    self.dx = clamp(self.dx, -m, m)
end

-- in water: Small / Normal rise to float half out of the surface, Big sinks
function Ball:applyWater(dt)
    local s = self:getSize()
    local want = s.waterSpeed
    if want < 0 then
        want = clamp((self.surfaceY - self:centerY()) * WATER_PULL, s.waterSpeed, WATER_SINK_SPEED)
    end
    self.dy = self.dy + (want - self.dy) * mmin(1, WATER_SMOOTH * dt)
end

-- inside a vent's air: the vertical speed eases toward floating at
-- floatBottom (rising up to it, or sinking gently back down to it)
function Ball:applyFloat(dt)
    local want = clamp((self:bottom() - self.floatBottom) * -FAN_PULL, -FAN_RISE_SPEED, FAN_SINK_SPEED)
    self.dy = self.dy + (want - self.dy) * mmin(1, FAN_SMOOTH * dt)
end

-- horizontal move with wall collision, level edges and block breaking.
-- Side wind (windX) moves the ball too, on top of its own speed.
function Ball:moveX(dt)
    local newX, tile = self.tileMap:sweepX(self.x, self.y, self.width, self.height, (self.dx + self.windX) * dt)

    -- Big ball rolling fast smashes through cracked blocks: every cracked
    -- block in the column it hits (not only the first tile found). Just
    -- touching / pushing while stopped never breaks anything.
    if tile and self:isBig() and mabs(self.dx) > BREAK_SPEED then
        local frontX = self.dx > 0 and (newX + self.width) or (newX - 1)
        if self.level:breakTilesInBox(frontX, self.y, 1, self.height) > 0 then
            self.dx = self.dx * 0.8
            -- move again: anything solid left in that column still stops us
            newX, tile = self.tileMap:sweepX(self.x, self.y, self.width, self.height, (self.dx + self.windX) * dt)
        end
    end
    local hitWall = tile ~= nil

    -- locked door: opens if we carry a key
    if tile and tile.door and self.level:tryOpenDoor(tile) then
        hitWall = false
    end

    local maxX = self.level.width - self.width
    if newX < 0 then newX, hitWall = 0, true
    elseif newX > maxX then newX, hitWall = maxX, true end
    self.x = newX

    if hitWall then
        if mabs(self.dx) > WALL_BOUNCE_MIN then
            self.dx = -self.dx * WALL_RESTITUTION
        else
            self.dx = 0
        end
    end
end

-- vertical move. Returns 'land' (+ impact speed), 'head', or nil
function Ball:moveY(dt)
    local oldBottom = self.y + self.height
    local newY, tile = self.tileMap:sweepY(self.x, self.y, self.width, self.height, self.dy * dt)

    -- falling onto a moving platform (only from above; before any tile below)
    if self.dy > 0 and self.grav > 0 then
        local p, top = self.level:platformLanding(self.x, self.width, oldBottom, newY + self.height)
        if p and top - self.height <= newY + 0.001 then
            self.y = top - self.height
            local impact = self.dy
            self.dy = 0
            return 'land', impact
        end
    end

    self.y = newY
    if tile then
        -- moving the way gravity pulls = landing (on the ceiling when flipped)
        if self.dy * self.grav > 0 then
            local impact = mabs(self.dy)
            -- Big ball falling onto cracked blocks smashes every one under it
            -- (not only the first tile found) and keeps falling - unless it
            -- is still standing half on something solid
            local edgeY = (self.grav > 0) and (newY + self.height) or (newY - 1)
            if self:isBig() and impact > BREAK_IMPACT
                and self.level:breakTilesInBox(self.x, edgeY, self.width, 1) > 0
                and not self:onGround() then
                self.dy = self.dy * 0.5
                return nil
            end
            self.dy = 0
            return 'land', impact
        else
            self.dy = 0
            self.jumping = false
            return 'head'
        end
    end
    return nil
end

-- is there solid ground (or a moving platform) directly under the ball?
-- Upside down: solid ceiling directly above it.
function Ball:onGround()
    if self.grav < 0 then
        return self.tileMap:boxCollides(self.x, self.y - 1, self.width, 1)
    end
    return self.tileMap:boxCollides(self.x, self.y + self.height, self.width, 1)
        or self.level:platformUnder(self) ~= nil
end

-- dir: 1 normal, -1 upside down. Returns true if gravity changed.
function Ball:setGravity(dir)
    if self.grav == dir or self.dead then return false end
    self.grav = dir
    self.dy = self.dy * 0.3          -- soften: the new "fall" starts gently
    self.jumping = false
    self.coyote = 0
    self.jumpBuffer = 0
    self.squashTimer = SQUASH_TIME
    self:changeState('air')
    return true
end

function Ball:jump()
    local s = self:getSize()
    self.dy = -s.jumpSpeed * self.grav
    self.jumpBuffer = 0
    self.coyote = 0
    self.jumping = true
    self.jumpTime = 0
    self:playBounce(0.6)
    self:changeState('air')
end

-- thrown upward by a spring at x = springX
function Ball:launch(speed, springX)
    -- line up with the spring so the ball flies straight up (only if there's room)
    local nx = springX - self.width / 2
    if not self.tileMap:boxCollides(nx, self.y, self.width, self.height) then
        self.x = nx
    end
    self.dx = self.dx * 0.3
    self.dy = -speed
    self.jumping = false        -- no jump cut: the spring always gives full height
    self.coyote = 0
    self.jumpBuffer = 0
    self.squashTimer = SQUASH_TIME
    self:changeState('air')
end

-- come back to life at bottom-centre (x, y): full air, short grace period.
-- Uses the start size if it fits there, otherwise Small.
function Ball:respawnAt(x, y)
    local index = BALL_START_SIZE
    local d = BALL_SIZES[index].diameter
    if self.tileMap:boxCollides(x - d / 2, y - d, d, d) then
        index = 1
        d = BALL_SIZES[index].diameter
    end
    self.sizeIndex = index
    self.width, self.height = d, d
    self.x, self.y = x - d / 2, y - d
    self.prevY = self.y
    self.dx, self.dy = 0, 0
    self.windX = 0
    self.floatBottom = nil
    self.inWater, self.submerged = false, false
    self.grav = 1                    -- checkpoints always bring normal gravity back

    self.dead = false
    self.air = AIR_MAX
    self.refillTimer = 0
    self.invuln = RESPAWN_INVULN_TIME
    self.squashTimer = 0
    self.jumpBuffer = 0
    self.coyote = 0
    self.jumping = false
    self:changeState('air')
end

-- called by the air state when the ball hits the ground
function Ball:land(impact)
    local s = self:getSize()
    if impact > 80 then self.squashTimer = SQUASH_TIME end

    -- hard landing: little dust puffs out to both sides
    if impact > LANDING_DUST_IMPACT then
        local cx, by = self:centerX(), (self.grav > 0) and (self:bottom() - 1) or (self.y + 1)
        local half = self.width / 2
        local dust = { colors = {'W', 'g'}, speed = {15, 40}, upward = true,
                       gravity = 60, life = {0.2, 0.4}, size = {1, 1} }
        self.level.particles:emit(cx - half, by, 3, dust)
        self.level.particles:emit(cx + half, by, 3, dust)
    end

    -- jump pressed just before landing: jump straight away (Big can't under water)
    if self.jumpBuffer > 0 and not (self.inWater and s.waterSpeed > 0) then
        self:jump()
        return
    end

    if impact > s.bounceMin then
        -- bounce back up, losing some energy
        self.dy = -impact * s.restitution * self.grav
        self.jumping = false
        self.coyote = COYOTE_TIME      -- a jump right after a bounce still works
        self:playBounce(mmin(1, impact / 400))
    else
        self:changeState('ground')
    end
end

function Ball:playBounce(volume)
    local snd = gSounds['bounce']
    snd:stop()
    snd:setPitch(self:getSize().pitch)
    snd:setVolume(volume)
    snd:play()
end

---------------------------------------------------------------------------
-- SIZE CHANGE
---------------------------------------------------------------------------

local function failSound()
    gSounds['hurt']:stop()
    gSounds['hurt']:play()
end

-- step: -1 smaller (free), +1 bigger (costs GROW_COST air).
-- Keeps the bottom-centre in place; growing needs room. Returns true if changed.
function Ball:changeSize(step)
    local newIndex = clamp(self.sizeIndex + step, 1, #BALL_SIZES)
    if newIndex == self.sizeIndex then return false end

    if step > 0 and self.air <= GROW_COST then
        failSound()        -- not enough air to grow
        return false
    end

    local d = BALL_SIZES[newIndex].diameter
    local cx, bottom = self:centerX(), self:bottom()
    local ny = bottom - d
    if self.grav < 0 then ny = self.y end    -- upside down: keep the top on the ceiling
    local baseX = cx - d / 2
    local maxX = self.level.width - d

    -- try centred first, then nudged left/right to squeeze into the space
    local grow = d - self.width
    local tries = {0, -grow / 2, grow / 2, -grow, grow}
    for i = 1, #tries do
        local nx = baseX + tries[i]
        if nx >= 0 and nx <= maxX and not self.tileMap:boxCollides(nx, ny, d, d) then
            self.sizeIndex = newIndex
            self.x, self.y = nx, ny
            self.width, self.height = d, d
            self.squashTimer = SQUASH_TIME
            if step > 0 then
                self.air = self.air - GROW_COST
            else
                -- letting air out: a little puff
                self.level.particles:emit(cx, bottom - d / 2, 4, {
                    colors = {'C', 'W'}, speed = {20, 50}, life = {0.2, 0.4}, size = {1, 1},
                })
            end
            local snd = gSounds[step > 0 and 'size-up' or 'size-down']
            snd:stop(); snd:play()
            return true
        end
    end

    failSound()            -- no room to grow
    return false
end

---------------------------------------------------------------------------
-- DRAWING
---------------------------------------------------------------------------

function Ball:render()
    if self.dead then return end

    -- flashing while invulnerable: hide every other 0.08s
    if self.invuln > 0 and mfloor(self.invuln / 0.08) % 2 == 0 then return end

    -- shape 1 round, 2 squash (just landed / just resized), 3 stretch (moving fast vertically)
    local shape = 1
    if self.squashTimer > 0 then shape = 2
    elseif not self.grounded and mabs(self.dy) > 200 then shape = 3 end
    local spins = Sprites.BALL_SPIN_FRAMES
    local spin = mfloor(self.roll / (math.pi * 2) * spins + 0.5) % spins
    local frame = Sprites.ballFrame(shape, spin)

    local name = 'ball-' .. self:getSize().name
    local quad = gFrames[name][frame]
    local _, _, w, h = quad:getViewport()
    if self.grav < 0 then
        -- upside down: drawn flipped, anchored at the top (squash stays on the ceiling)
        love.graphics.draw(gTextures[name], quad, mfloor(self:centerX() - w / 2), mfloor(self.y) + h, 0, 1, -1)
        return
    end
    -- anchor at bottom-centre so squash stays on the ground
    SpriteBuilder.draw(name, frame, self:centerX() - w / 2, self:bottom() - h)
end
