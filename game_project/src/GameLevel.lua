--[[
    Inflate - GameLevel
    Holds everything in one level: the tile map, objects, particles, start
    point and goal. Built by LevelMaker. Also handles what happens when the
    ball touches things (gems, pumps, enemies, spikes, goal).
]]

GameLevel = Class{}

local mfloor = math.floor
local SPIKE_BOX = {2, 9, 12, 7}      -- the part of a spikes tile that hurts

function GameLevel:init(def)
    self.name = def.name
    self.tileMap = def.tileMap
    self.objects = def.objects
    self.enemies = def.enemies or {}
    for i = 1, #self.enemies do self.enemies[i].level = self end
    self.spawnX = def.spawnX       -- bottom-centre of the start cell
    self.spawnY = def.spawnY
    self.width = self.tileMap.width
    self.height = self.tileMap.height
    self.theme = def.theme or 'sky'

    -- where the ball comes back after popping (bottom-centre); moved by checkpoints
    self.checkpointX = self.spawnX
    self.checkpointY = self.spawnY

    self.keys = 0                  -- keys being carried
    self.message = nil             -- short text shown mid-screen ("FIND THE KEY!")
    self.messageTimer = 0

    self.particles = Particles(320)
    self.completed = false
    self.time = 0

    -- fans: every vent / blower tile and the area of air it moves
    self.fans = {}
    self.fanClock = 0
    local tm = self.tileMap
    for r = 1, tm.rows do
        for c = 1, tm.cols do
            local t = tm:getTile(c, r)
            if t and t.fan then
                self.fans[#self.fans + 1] = { tile = t, spin = 0, puff = math.random() * 0.1, power = 1 }
            end
        end
    end
    self:updateFanAreas()

    -- bubble streams: a column of bubbles rising from the vent to the surface
    self.bubbleStreams = {}
    for i = 1, #self.objects do
        local o = self.objects[i]
        if o.type == 'bubbles' then
            local top = o.y + 8
            local n = 0
            while n < BUBBLE_RANGE and tm:isWaterAt(o.x + 8, top - TILE_SIZE)
                and not tm:isSolidAt(o.x + 8, top - TILE_SIZE) do
                top = top - TILE_SIZE
                n = n + 1
            end
            self.bubbleStreams[#self.bubbleStreams + 1] = {
                x = o.x + 2, w = 12, top = top - 8, bottom = o.y + 16, puff = 0,
            }
        end
    end

    -- gates: groups of plates + gate tiles. A group is open while all its
    -- plates are active (see updateGates)
    self.gateGroups = {}
    local function group(n)
        local g = self.gateGroups[n]
        if not g then
            g = { plates = {}, tiles = {}, open = false }
            self.gateGroups[n] = g
        end
        return g
    end
    for i = 1, #self.objects do
        local o = self.objects[i]
        if o.type == 'plate' then table.insert(group(o.group).plates, o) end
    end
    for r = 1, tm.rows do
        for c = 1, tm.cols do
            local t = tm:getTile(c, r)
            if t and t.gate then table.insert(group(t.gateGroup).tiles, t) end
        end
    end

    -- gravity orbs (just a list, to light them up)
    self.orbs = {}
    for i = 1, #self.objects do
        if self.objects[i].type == 'orb' then self.orbs[#self.orbs + 1] = self.objects[i] end
    end

    -- moving platforms (see LevelMaker legend). pos: pixels along the path
    self.platforms = {}
    local defs = def.platforms or {}
    for i = 1, #defs do
        local d = defs[i]
        local x0, y0 = (d[1] - 1) * TILE_SIZE, (d[2] - 1) * TILE_SIZE
        local x1, y1 = (d[4] - 1) * TILE_SIZE, (d[5] - 1) * TILE_SIZE
        self.platforms[i] = {
            x = x0, y = y0, w = (d[3] or 3) * TILE_SIZE,
            x0 = x0, y0 = y0, x1 = x1, y1 = y1,
            dist = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2),
            pos = 0, dir = 1, pause = 0,
            speed = d[6] or PLATFORM_SPEED,
            wake = d[7] or false,
            awake = not d[7],
            group = d[8],
            moving = false,
            sag = 0, prevTop = y0,
        }
    end

    -- waterfalls (W): a column of falling water from its source cell down to
    -- solid ground or a pool's surface
    self.waterfalls = {}
    for _, w in ipairs(def.waterfalls or {}) do
        local r = w.row
        while r <= tm.rows do
            local t = tm:getTile(w.col, r)
            if (t and t.solid) or tm:isWater(w.col, r) then break end
            r = r + 1
        end
        self.waterfalls[#self.waterfalls + 1] = {
            x = (w.col - 1) * TILE_SIZE,
            top = (w.row - 1) * TILE_SIZE,
            bottom = (r - 1) * TILE_SIZE,
            pool = tm:isWater(w.col, r),
            puff = math.random() * 0.2,
        }
    end

    -- things thrown by enemies (monkeys' coconuts)
    self.projectiles = {}

    -- set by PlayState: onShake(amount, duration), onFreeze(seconds)
    self.onShake = nil
    self.onFreeze = nil

    self.totalGems = 0
    self.gemsCollected = 0
    for i = 1, #self.objects do
        if self.objects[i].type == 'gem' then self.totalGems = self.totalGems + 1 end
    end
end

function GameLevel:update(dt, ball)
    self.time = self.time + dt
    self:updateFans(dt, ball)
    self:updateBubbles(dt, ball)
    self:updateGates(dt, ball)
    self:updatePlatforms(dt, ball)

    -- gravity orbs light up when touching them would flip the ball
    local orbs = self.orbs
    for i = 1, #orbs do orbs[i].lit = (ball.grav ~= orbs[i].dir) end

    local objects = self.objects
    for i = 1, #objects do
        objects[i]:update(dt)
    end

    local enemies = self.enemies
    for i = #enemies, 1, -1 do
        local e = enemies[i]
        e:update(dt, ball)
        if e.remove then swapRemove(enemies, i) end
    end

    self:updateWaterfalls(dt, ball)
    self:updateProjectiles(dt)
    self.particles:update(dt)

    if self.messageTimer > 0 then
        self.messageTimer = self.messageTimer - dt
        if self.messageTimer <= 0 then self.message = nil end
    end
end

function GameLevel:showMessage(text)
    self.message = text
    self.messageTimer = MESSAGE_TIME
end

-- s = {pixels, seconds} (see SHAKE_SMALL / SHAKE_BIG)
function GameLevel:shake(s)
    if self.onShake then self.onShake(s[1], s[2]) end
end

function GameLevel:freeze(seconds)
    if self.onFreeze then self.onFreeze(seconds) end
end

---------------------------------------------------------------------------
-- BALL VS ENEMIES
--   Big ball landing on top  -> squash (any enemy, even a stunned one)
--   Big ball rolling fast    -> knocks a crawler over (stunned, harmless)
--   anything else            -> the ball gets hurt
--   stunned / squashed enemies are harmless
---------------------------------------------------------------------------

function GameLevel:checkEnemies(ball)
    local enemies = self.enemies
    for i = 1, #enemies do
        local e = enemies[i]
        -- (a biting plant reaches up: its hitbox grows by e.reach)
        local top = e.y - e.reach
        if not e.squashed and aabb(ball.x, ball.y, ball.width, ball.height,
                                   e.x, top, e.width, e.height + e.reach) then
            local prevBottom = ball.prevY + ball.height
            -- (only when falling down onto it: not upside down)
            local stomp = ball.grav > 0 and ball.dy >= 0 and prevBottom <= top + STOMP_TOLERANCE

            if ball:isBig() and stomp and not e.unkillable then   -- Shades, plants, piranhas can't be squashed
                e:squash()
                ball.dy = -STOMP_BOUNCE
                ball.jumping = false
                ball.coyote = COYOTE_TIME
                if ball.grounded then ball:changeState('air') end
                self.particles:emit(e:centerX(), e:centerY(), 12, {
                    colors = {'d', 'g', 'W', 'K'}, speed = {50, 120}, upward = true,
                    gravity = 400, life = {0.4, 0.7}, size = {1, 2},
                })
                gSounds['break']:stop(); gSounds['break']:play()
                self:shake(SHAKE_SMALL)
                self:freeze(HIT_FREEZE_TIME)

            elseif not e.harmless then
                if ball:isBig() and e.stunnable and math.abs(ball.dx) > KNOCK_SPEED then
                    e:stun(sign(ball.dx))
                    ball.dx = -ball.dx * 0.3
                    gSounds['hurt']:stop(); gSounds['hurt']:play()
                    self:shake(SHAKE_SMALL)
                else
                    if ball:hurt(ENEMY_DAMAGE, e:centerX()) and e.kind == 'shade' then
                        e.hitPause = SHADE_HIT_PAUSE
                    end
                    if ball.dead then return end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- BALL INTERACTIONS
---------------------------------------------------------------------------

function GameLevel:checkBall(ball)
    if ball.dead or self.completed then return end
    local bx, by, bw, bh = ball.x, ball.y, ball.width, ball.height

    -- objects (backwards so collected gems can be removed safely)
    local objects = self.objects
    for i = #objects, 1, -1 do
        local o = objects[i]
        local hx, hy, hw, hh = o:getHitbox()
        if aabb(bx, by, bw, bh, hx, hy, hw, hh) then
            if o.type == 'gem' then
                self.gemsCollected = self.gemsCollected + 1
                self.particles:emit(o.x + 4, o.y + 4, 8, {
                    colors = {'Y', 'W'}, speed = {30, 70}, gravity = 60,
                    life = {0.3, 0.6}, size = {1, 1},
                })
                gSounds['gem']:stop(); gSounds['gem']:play()
                swapRemove(objects, i)

            elseif o.type == 'pump' then
                if o.cooldown <= 0 and ball:refill() then
                    o.pressTimer = PUMP_PRESS_TIME
                    o.cooldown = PUMP_COOLDOWN
                    self.particles:emit(o.x + 8, o.y + 8, 6, {
                        colors = {'C', 'W'}, speed = {20, 50}, upward = true,
                        gravity = -20, life = {0.3, 0.6}, size = {1, 2},
                    })
                    gSounds['pump']:stop(); gSounds['pump']:play()
                end

            elseif o.type == 'spring' then
                -- only when coming down onto it (or rolling over it)
                if ball.grav > 0 and ball.dy >= 0 and o.cooldown <= 0 then
                    ball:launch(SPRING_SPEED, o.x + 8)
                    o.pressTimer = SPRING_PRESS_TIME
                    o.cooldown = 0.15
                    self.particles:emit(o.x + 8, o.y + 8, 6, {
                        colors = {'W', 'g'}, speed = {20, 50}, upward = true,
                        gravity = 80, life = {0.2, 0.4}, size = {1, 1},
                    })
                    gSounds['spring']:stop(); gSounds['spring']:play()
                    bx, by = ball.x, ball.y     -- the ball may have been centred on the spring
                end

            elseif o.type == 'orb' then
                if ball:setGravity(o.dir) then
                    self.particles:emit(o.x + 8, o.y + 8, 10, {
                        colors = o.dir < 0 and {'C', 'W'} or {'Y', 'W'}, speed = {30, 80},
                        gravity = 0, life = {0.3, 0.6}, size = {1, 2},
                    })
                    gSounds['flip']:stop(); gSounds['flip']:play()
                end

            elseif o.type == 'checkpoint' then
                if not o.active then
                    for j = 1, #objects do
                        if objects[j].type == 'checkpoint' then objects[j].active = false end
                    end
                    o.active = true
                    self.checkpointX = o.x + 8
                    self.checkpointY = o.y + TILE_SIZE
                    self.particles:emit(o.x + 6, o.y + 4, 10, {
                        colors = {'L', 'Y', 'W'}, speed = {30, 80}, upward = true,
                        gravity = 150, life = {0.4, 0.8}, size = {1, 2},
                    })
                    gSounds['checkpoint']:stop(); gSounds['checkpoint']:play()
                    self:showMessage('CHECKPOINT!')
                end

            elseif o.type == 'key' then
                self.keys = self.keys + 1
                self.particles:emit(o.x + 6, o.y + 3, 10, {
                    colors = {'Y', 'O', 'W'}, speed = {30, 80}, gravity = 60,
                    life = {0.3, 0.7}, size = {1, 2},
                })
                gSounds['key']:stop(); gSounds['key']:play()
                self:showMessage('GOT THE KEY!')
                swapRemove(objects, i)

            elseif o.type == 'goal' then
                self.completed = true
                gSounds['win']:play()
                self.particles:emit(o.x + 8, o.y + 6, 20, {
                    colors = {'Y', 'O', 'W', 'L'}, speed = {50, 120}, upward = true,
                    gravity = 200, life = {0.6, 1.2}, size = {1, 2},
                })
                return
            end
        end
    end

    self:checkEnemies(ball)
    if ball.dead then return end

    -- coconuts
    local ps = self.projectiles
    for i = #ps, 1, -1 do
        local p = ps[i]
        if aabb(bx, by, bw, bh, p.x, p.y, 6, 6) then
            self:burstCoconut(p)
            swapRemove(ps, i)
            ball:hurt(COCONUT_DAMAGE, p.x + 3)
            if ball.dead then return end
        end
    end

    -- spikes: only the pointy bottom part of the tile hurts
    local tm = self.tileMap
    local c1, c2 = mfloor(bx / TILE_SIZE) + 1, mfloor((bx + bw - 0.001) / TILE_SIZE) + 1
    local r1, r2 = mfloor(by / TILE_SIZE) + 1, mfloor((by + bh - 0.001) / TILE_SIZE) + 1
    for r = r1, r2 do
        for c = c1, c2 do
            local t = tm:getTile(c, r)
            local hb = t and t.hazard and (t.hazardBox or SPIKE_BOX)
            if hb and aabb(bx, by, bw, bh, t.x + hb[1], t.y + hb[2], hb[3], hb[4]) then
                ball:hurt(SPIKE_DAMAGE, ball:centerX())
                return
            end
        end
    end
end

-- the ball bumped into a door tile. With a key: the door (all door tiles touching
-- this one) opens and true is returned. Without: a hint, and false.
function GameLevel:tryOpenDoor(tile)
    if self.keys <= 0 then
        if self.messageTimer <= 0 then
            self:showMessage('FIND THE KEY!')
            gSounds['hurt']:stop(); gSounds['hurt']:play()
        end
        return false
    end

    self.keys = self.keys - 1
    local tm = self.tileMap
    local stack = {{tile.col, tile.row}}
    while #stack > 0 do
        local cell = table.remove(stack)
        local c, r = cell[1], cell[2]
        local t = tm:getTile(c, r)
        if t and t.door then
            tm:removeTile(c, r)
            self.particles:emit(t.x + 8, t.y + 8, 8, {
                colors = {'n', 'b', 'O'}, speed = {40, 110}, upward = true,
                gravity = 480, life = {0.5, 0.9}, size = {2, 3},
            })
            stack[#stack + 1] = {c + 1, r}
            stack[#stack + 1] = {c - 1, r}
            stack[#stack + 1] = {c, r + 1}
            stack[#stack + 1] = {c, r - 1}
        end
    end
    gSounds['door']:stop(); gSounds['door']:play()
    self:updateFanAreas()
    self:shake(SHAKE_SMALL)
    self:showMessage('UNLOCKED!')
    return true
end

---------------------------------------------------------------------------
-- FANS
--   vent (blows up): inside its air column the ball floats at a height that
--   depends on its size (BALL_SIZES fanHover): Small high, Normal a little,
--   Big not at all.
--   blower (blows sideways): pushes the ball (BALL_SIZES windPush): Small is
--   blown away, Normal struggles, Big walks through.
--   U / V vents take turns: on, slowing down (warning), off.
---------------------------------------------------------------------------

-- 0..1: how hard a fan of this group blows right now
local function fanPower(group, clock)
    if group == 0 then return 1 end
    local cycle = FAN_ON_TIME + FAN_WARN_TIME + FAN_OFF_TIME
    local phase = clock % cycle
    if group == 2 then phase = (clock - FAN_ON_TIME) % cycle end
    if phase < FAN_ON_TIME then return 1 end
    if phase < FAN_ON_TIME + FAN_WARN_TIME then
        return 1 - (phase - FAN_ON_TIME) / FAN_WARN_TIME
    end
    return 0
end

-- works out each fan's air area (it stops at solid tiles). Called again when
-- tiles disappear (smashed blocks, opened doors).
function GameLevel:updateFanAreas()
    local tm = self.tileMap
    for i = 1, #self.fans do
        local f = self.fans[i]
        local t = f.tile
        if t.fan == 'up' then
            local n = 0
            while n < FAN_RANGE and t.y - 8 - n * TILE_SIZE > 0
                and not tm:isSolidAt(t.x + 8, t.y - 8 - n * TILE_SIZE) do
                n = n + 1
            end
            f.x, f.w = t.x, TILE_SIZE
            f.y, f.h = t.y - n * TILE_SIZE, n * TILE_SIZE
        else
            local dir = (t.fan == 'right') and 1 or -1
            local n = 0
            while n < WIND_RANGE
                and not tm:isSolidAt(t.x + 8 + dir * (n + 1) * TILE_SIZE, t.y + 8) do
                n = n + 1
            end
            f.dir = dir
            f.y, f.h = t.y, TILE_SIZE
            f.w = n * TILE_SIZE
            f.x = (dir > 0) and (t.x + TILE_SIZE) or (t.x - f.w)
        end
    end
end

function GameLevel:updateFans(dt, ball)
    if #self.fans == 0 then return end
    self.fanClock = self.fanClock + dt
    local bx, by = ball:centerX(), ball:centerY()
    for i = 1, #self.fans do
        local f = self.fans[i]
        local t = f.tile
        f.power = fanPower(t.fanGroup, self.fanClock)

        -- blades: frames 1-4 blowing, 5-8 off (blades keep their angle)
        f.spin = f.spin + dt * FAN_SPIN_FPS * f.power
        t.frame = math.floor(f.spin) % 4 + 1 + (f.power > 0 and 0 or 4)

        -- air streaks (only near the ball, to save particles)
        if f.power > 0.15 and f.w > 0 and f.h > 0 and
            math.abs(f.x + f.w / 2 - bx) < 360 and math.abs(f.y + f.h / 2 - by) < 240 then
            f.puff = f.puff - dt
            if f.puff <= 0 then
                f.puff = 0.07
                if t.fan == 'up' then
                    local speed = 90 * f.power
                    self.particles:emit(t.x + 2 + math.random() * 12, t.y - 1, 1, {
                        colors = {'C', 'W', 'C'}, angle = -math.pi / 2, spread = 0.08,
                        speed = {speed * 0.8, speed * 1.2},
                        life = {f.h / speed * 0.5, f.h / speed * 0.9}, size = {1, 1},
                    })
                else
                    local speed = 170 * f.power
                    local startX = (f.dir > 0) and f.x or (f.x + f.w)
                    self.particles:emit(startX, t.y + 2 + math.random() * 12, 1, {
                        colors = {'C', 'W', 'g'}, angle = (f.dir > 0) and 0 or math.pi, spread = 0.05,
                        speed = {speed * 0.8, speed * 1.2},
                        life = {f.w / speed * 0.6, f.w / speed}, size = {1, 1},
                    })
                end
            end
        end
    end
end

-- the air acting on the ball right now. Returns:
--   floatBottom  y the ball's bottom is pulled to by a vent (nil = no vent)
--   windX        sideways push from blowers (px/s)
function GameLevel:airAt(ball)
    local fans = self.fans
    if #fans == 0 then return nil, 0 end
    local s = ball:getSize()
    local cx, cy, bottom = ball:centerX(), ball:centerY(), ball:bottom()
    local floatBottom, windX = nil, 0
    for i = 1, #fans do
        local f = fans[i]
        if f.power > 0 and cx >= f.x and cx < f.x + f.w then
            if f.tile.fan == 'up' then
                local ventTop = f.y + f.h
                local hover = s.fanHover * f.power
                if hover > 1 and bottom > f.y and bottom <= ventTop + 1 then
                    local target = ventTop - hover
                    if not floatBottom or target < floatBottom then floatBottom = target end
                end
            elseif cy >= f.y and cy < f.y + f.h then
                local push = f.dir * s.windPush * f.power
                if math.abs(push) > math.abs(windX) then windX = push end
            end
        end
    end
    return floatBottom, windX
end

---------------------------------------------------------------------------
-- WATER
---------------------------------------------------------------------------

function GameLevel:updateBubbles(dt, ball)
    local bx, by = ball:centerX(), ball:centerY()
    for i = 1, #self.bubbleStreams do
        local b = self.bubbleStreams[i]
        if math.abs(b.x - bx) < 360 and math.abs((b.top + b.bottom) / 2 - by) < 300 then
            b.puff = b.puff - dt
            if b.puff <= 0 then
                b.puff = 0.12
                local speed = 40
                self.particles:emit(b.x + 3 + math.random() * 6, b.bottom - 6, 1, {
                    colors = {'W', 'C', 'C'}, angle = -math.pi / 2, spread = 0.15,
                    speed = {speed * 0.8, speed * 1.2},
                    life = {(b.bottom - b.top) / speed * 0.7, (b.bottom - b.top) / speed},
                    size = {1, 2},
                })
            end
        end
    end
end

-- is the ball inside a bubble stream? (refills air under water)
function GameLevel:bubblesAt(ball)
    local cx, cy = ball:centerX(), ball:centerY()
    for i = 1, #self.bubbleStreams do
        local b = self.bubbleStreams[i]
        if cx >= b.x and cx < b.x + b.w and cy >= b.top and cy < b.bottom then return true end
    end
    return false
end

-- a splash at the water surface; strength = falling / rising speed
function GameLevel:splash(x, y, strength)
    local s = math.min(1, strength / 300)
    self.particles:emit(x, y, 4 + math.floor(s * 8), {
        colors = {'W', 'C', 'S'}, speed = {30, 60 + s * 70}, upward = true,
        gravity = 400, life = {0.25, 0.5}, size = {1, 2},
    })
    local snd = gSounds['splash']
    snd:stop()
    snd:setVolume(0.4 + s * 0.6)
    snd:play()
end

-- see-through water with a shimmering surface line. Drawn after the ball and
-- enemies so everything under water looks under water.
function GameLevel:renderWater(camX, camY)
    local tm = self.tileMap
    if not tm.hasWater then return end
    local lg = love.graphics
    local firstCol = math.max(1, mfloor(camX / TILE_SIZE) + 1)
    local lastCol  = math.min(tm.cols, mfloor((camX + VIRTUAL_WIDTH) / TILE_SIZE) + 1)
    local firstRow = math.max(1, mfloor(camY / TILE_SIZE) + 1)
    local lastRow  = math.min(tm.rows, mfloor((camY + VIRTUAL_HEIGHT) / TILE_SIZE) + 1)
    local water = tm.water

    Palette.set('S', 0.3)
    for r = firstRow, lastRow do
        local row = water[r]
        for c = firstCol, lastCol do
            if row[c] then
                lg.rectangle('fill', (c - 1) * TILE_SIZE, (r - 1) * TILE_SIZE, TILE_SIZE, TILE_SIZE)
            end
        end
    end

    -- surface: a 1px light line that ripples up and down by a pixel
    local t = self.time
    for pass = 1, 2 do
        if pass == 1 then Palette.set('W', 0.85) else Palette.set('C', 0.7) end
        for r = firstRow, lastRow do
            local row, above = water[r], water[r - 1]
            for c = firstCol, lastCol do
                if row[c] and not (above and above[c]) and not tm:getTile(c, r - 1) then
                    local x0, y0 = (c - 1) * TILE_SIZE, (r - 1) * TILE_SIZE
                    for px = 0, TILE_SIZE - 1 do
                        local wx = x0 + px
                        local off = (math.sin(wx * 0.35 + t * 3) > 0.2) and 0 or 1
                        lg.rectangle('fill', wx, y0 + off + (pass - 1), 1, 1)
                    end
                end
            end
        end
    end
    lg.setColor(1, 1, 1, 1)
end

---------------------------------------------------------------------------
-- PRESSURE PLATES + GATES
--   Only the Big ball presses a plate (Small / Normal get "TOO LIGHT!").
--   hold plate   active while pressed, and GATE_HOLD_GRACE seconds after
--   timer plate  pressing starts its timer: active until it runs out (ticking)
--   A gate never closes on the ball or an enemy: it waits until they move.
---------------------------------------------------------------------------

-- is anything standing in this gate tile?
function GameLevel:gateBlocked(t, ball)
    if not ball.dead and aabb(ball.x, ball.y, ball.width, ball.height, t.x, t.y, TILE_SIZE, TILE_SIZE) then
        return true
    end
    for i = 1, #self.enemies do
        local e = self.enemies[i]
        if not e.squashed and aabb(e.x, e.y, e.width, e.height, t.x, t.y, TILE_SIZE, TILE_SIZE) then
            return true
        end
    end
    return false
end

function GameLevel:updateGates(dt, ball)
    local big = ball:isBig() and not ball.dead
    for _, g in pairs(self.gateGroups) do
        local allActive = #g.plates > 0
        for i = 1, #g.plates do
            local p = g.plates[i]
            local hx, hy, hw, hh = p:getHitbox()
            local onIt = not ball.dead and aabb(ball.x, ball.y, ball.width, ball.height + 1, hx, hy, hw, hh)
            local wasPressed = p.pressed
            p.pressed = onIt and big

            if onIt and not big and self.messageTimer <= 0 then
                self:showMessage('TOO LIGHT!')
            end
            if p.pressed and not wasPressed then
                gSounds['plate']:stop(); gSounds['plate']:play()
            end

            if p.duration then
                -- timer plate: (re)starts while pressed, then counts down with ticks
                if p.pressed then
                    p.remaining = p.duration
                elseif p.remaining > 0 then
                    p.remaining = math.max(0, p.remaining - dt)
                    p.tick = p.tick - dt
                    if p.tick <= 0 and p.remaining > 0 then
                        p.tick = (p.remaining < TIMER_FAST_AT) and TIMER_TICK_FAST or TIMER_TICK
                        gSounds['tick']:stop(); gSounds['tick']:play()
                    end
                end
            else
                -- hold plate: a short grace after rolling off
                if p.pressed then
                    p.remaining = GATE_HOLD_GRACE
                else
                    p.remaining = math.max(0, p.remaining - dt)
                end
            end
            if not (p.pressed or p.remaining > 0) then allActive = false end
        end

        if allActive and not g.open then
            g.open = true
            for i = 1, #g.tiles do
                g.tiles[i].solid = false
                g.tiles[i].frame = 2
            end
            if #g.tiles > 0 then gSounds['gate']:stop(); gSounds['gate']:play() end
        elseif not allActive and g.open then
            local blocked = false
            for i = 1, #g.tiles do
                if self:gateBlocked(g.tiles[i], ball) then blocked = true; break end
            end
            if not blocked then
                g.open = false
                for i = 1, #g.tiles do
                    g.tiles[i].solid = true
                    g.tiles[i].frame = 1
                end
                if #g.tiles > 0 then gSounds['gate']:stop(); gSounds['gate']:play() end
            end
        end
    end
end

---------------------------------------------------------------------------
-- MOVING PLATFORMS
--   One-way: the ball lands on top (never from below or the side), so a
--   platform can never squash it. Standing on one carries the ball along.
--   Big makes a platform sag a little and move slower.
---------------------------------------------------------------------------

local function platTop(p) return p.y + p.sag end

-- the platform the ball is standing on, or nil. centre: only if the
-- ball's centre is over it (a ball mostly on a ledge isn't carried off)
function GameLevel:platformUnder(ball, centre)
    local bottom = ball.y + ball.height
    local cx = ball.x + ball.width / 2
    local ps = self.platforms
    for i = 1, #ps do
        local p = ps[i]
        local over
        if centre then over = cx >= p.x and cx <= p.x + p.w
        else over = ball.x < p.x + p.w and ball.x + ball.width > p.x end
        if over
            and math.abs(bottom - platTop(p)) <= 1.5 then
            return p
        end
    end
    return nil
end

-- a falling box (x, w) whose bottom goes from oldBottom to newBottom: the
-- platform it lands on and that platform's top, or nil
function GameLevel:platformLanding(x, w, oldBottom, newBottom)
    local ps = self.platforms
    for i = 1, #ps do
        local p = ps[i]
        local top = platTop(p)
        if x < p.x + p.w and x + w > p.x
            and oldBottom <= math.max(top, p.prevTop) + 1 and newBottom >= top then
            return p, top
        end
    end
    return nil
end

function GameLevel:updatePlatforms(dt, ball)
    local ps = self.platforms
    local tm = self.tileMap
    for i = 1, #ps do
        local p = ps[i]
        local rider = not ball.dead and ball.grounded and ball.grav > 0
            and self:platformUnder(ball, true) == p
        local big = rider and ball:isBig()
        p.prevTop = platTop(p)
        local ox = p.x

        if rider and not p.awake then
            p.awake = true
            p.pause = 0.3
        end
        p.sag = p.sag + ((big and PLATFORM_SAG or 0) - p.sag) * math.min(1, 10 * dt)

        local speed = p.speed * (big and PLATFORM_BIG_SLOW or 1) * dt
        p.moving = false
        if p.dist > 0 then
            if p.group then
                -- linked to plates: while they are active it carries a rider to
                -- the end (and waits there); when they stop it goes back
                local g = self.gateGroups[p.group]
                if g and g.open then
                    if rider and p.pos < p.dist then
                        p.pos = math.min(p.dist, p.pos + speed); p.moving = true
                    end
                elseif p.pos > 0 then
                    p.pos = math.max(0, p.pos - speed); p.moving = true
                end
            elseif p.awake then
                if p.pause > 0 then
                    p.pause = p.pause - dt
                else
                    p.moving = true
                    p.pos = p.pos + p.dir * speed
                    if p.pos >= p.dist then
                        p.pos, p.dir, p.pause = p.dist, -1, PLATFORM_PAUSE
                    elseif p.pos <= 0 then
                        p.pos, p.dir, p.pause = 0, 1, PLATFORM_PAUSE
                    end
                end
            end
            local k = p.pos / p.dist
            p.x = p.x0 + (p.x1 - p.x0) * k
            p.y = p.y0 + (p.y1 - p.y0) * k
        end

        -- carry the rider (walls still stop it)
        if rider then
            local dx = p.x - ox
            if dx ~= 0 then
                ball.x = (tm:sweepX(ball.x, ball.y, ball.width, ball.height, dx))
            end
            local want = platTop(p) - ball.height
            ball.y = (tm:sweepY(ball.x, ball.y, ball.width, ball.height, want - ball.y))
        end
    end
end

-- rails (dotted path) and the platforms themselves
function GameLevel:renderPlatforms(camX)
    local ps = self.platforms
    if #ps == 0 then return end
    local left, right = camX - 64, camX + VIRTUAL_WIDTH + 64

    Palette.set('g', 0.45)
    for i = 1, #ps do
        local p = ps[i]
        if p.dist > 0 and math.max(p.x0, p.x1) + p.w >= left and math.min(p.x0, p.x1) <= right then
            local ax, ay = p.x0 + p.w / 2, p.y0 + 4
            local bx, by = p.x1 + p.w / 2, p.y1 + 4
            local n = mfloor(p.dist / 6)
            for k = 0, n do
                local f = k / math.max(1, n)
                love.graphics.rectangle('fill', mfloor(ax + (bx - ax) * f), mfloor(ay + (by - ay) * f), 1, 1)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)

    for i = 1, #ps do
        local p = ps[i]
        if p.x + p.w >= left and p.x <= right then
            local x, y = mfloor(p.x), mfloor(platTop(p))
            local n = p.w / TILE_SIZE
            for k = 1, n do
                local frame = (k == 1) and 1 or ((k == n) and 3 or 2)
                SpriteBuilder.draw('lift', frame, x + (k - 1) * TILE_SIZE, y)
            end
            -- light: green while moving, yellow while waiting
            Palette.set(p.moving and 'L' or 'Y')
            love.graphics.rectangle('fill', x + p.w / 2 - 1, y + 2, 2, 2)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
end

-- removes every breakable tile overlapping the box, with debris. Returns how many.
function GameLevel:breakTilesInBox(x, y, w, h)
    local tm = self.tileMap
    local c1, c2 = mfloor(x / TILE_SIZE) + 1, mfloor((x + w - 0.001) / TILE_SIZE) + 1
    local r1, r2 = mfloor(y / TILE_SIZE) + 1, mfloor((y + h - 0.001) / TILE_SIZE) + 1
    local count = 0
    for r = r1, r2 do
        for c = c1, c2 do
            local t = tm:getTile(c, r)
            if t and t.breakable then
                tm:removeTile(c, r)
                count = count + 1
                self.particles:emit(t.x + 8, t.y + 8, 8, {
                    colors = {'g', 'd', 'D'}, speed = {50, 130}, upward = true,
                    gravity = 520, life = {0.5, 0.9}, size = {2, 3},
                })
            end
        end
    end
    if count > 0 then
        gSounds['break']:stop(); gSounds['break']:play()
        self:shake(SHAKE_SMALL)
        self:updateFanAreas()
    end
    return count
end

---------------------------------------------------------------------------
-- WATERFALLS
--   Inside a waterfall the ball is pushed down (BALL_SIZES fallPush): the
--   Small ball can't jump up through one, Big hardly notices it.
---------------------------------------------------------------------------

-- the extra downward push on the ball right now (px/s^2, 0 = none)
function GameLevel:waterfallAt(ball)
    local falls = self.waterfalls
    if #falls == 0 then return 0 end
    local cx, cy = ball:centerX(), ball:centerY()
    for i = 1, #falls do
        local f = falls[i]
        if cx >= f.x and cx < f.x + TILE_SIZE and cy >= f.top and cy < f.bottom then
            return ball:getSize().fallPush
        end
    end
    return 0
end

-- spray where the water lands (only near the ball, to save particles)
function GameLevel:updateWaterfalls(dt, ball)
    local falls = self.waterfalls
    local bx, by = ball:centerX(), ball:centerY()
    for i = 1, #falls do
        local f = falls[i]
        if math.abs(f.x + 8 - bx) < 300 and math.abs(f.bottom - by) < 220 then
            f.puff = f.puff - dt
            if f.puff <= 0 then
                f.puff = 0.09
                self.particles:emit(f.x + 2 + math.random() * 12, f.bottom - 1, 1, {
                    colors = {'W', 'C', 'W'}, speed = {25, 60}, upward = true,
                    gravity = 300, life = {0.2, 0.45}, size = {1, 1},
                })
            end
        end
    end
end

-- see-through falling water with streaks running down it. Drawn after the
-- ball (like water), so a ball behind a waterfall is half hidden.
function GameLevel:renderWaterfalls(camX, camY)
    local falls = self.waterfalls
    if #falls == 0 then return end
    local lg = love.graphics
    local t = self.time
    local viewTop, viewBottom = camY - 8, camY + VIRTUAL_HEIGHT + 8
    for i = 1, #falls do
        local f = falls[i]
        local x = f.x
        if x + TILE_SIZE >= camX and x <= camX + VIRTUAL_WIDTH then
            local y0 = math.max(f.top, mfloor(viewTop))
            local y1 = math.min(f.bottom, math.ceil(viewBottom))
            if y1 > y0 then
                Palette.set('S', 0.5)
                lg.rectangle('fill', x, y0, TILE_SIZE, y1 - y0)
                Palette.set('C', 0.7)
                lg.rectangle('fill', x, y0, 1, y1 - y0)
                lg.rectangle('fill', x + TILE_SIZE - 1, y0, 1, y1 - y0)
                -- streaks: 1px dashes falling fast, each column a bit out of step
                for px = 1, TILE_SIZE - 2 do
                    local offset = (px * 7) % 12 + t * 150
                    local first = f.top + (offset % 12) - 12
                    if first < y0 - 12 then first = first + mfloor((y0 - 12 - first) / 12) * 12 end
                    Palette.set((px % 3 == 0) and 'C' or 'W', 0.75)
                    for y = first, y1, 12 do
                        local a, b = math.max(y, f.top), math.min(y + 5, f.bottom)
                        if b > a then lg.rectangle('fill', x + px, mfloor(a), 1, mfloor(b) - mfloor(a)) end
                    end
                end
                -- white foam bubbling where it lands
                if f.bottom <= y1 then
                    Palette.set('W', 0.85)
                    for k = 0, 4 do
                        local wob = math.sin(t * 9 + k * 1.7 + f.x) * 1.5
                        lg.rectangle('fill', mfloor(x - 2 + k * 4 + wob), f.bottom - 3 + mfloor(wob * 0.5), 3, 2)
                    end
                end
            end
        end
    end
    lg.setColor(1, 1, 1, 1)
end

---------------------------------------------------------------------------
-- COCONUTS (thrown by monkeys)
---------------------------------------------------------------------------

function GameLevel:throwCoconut(x, y, dx, dy)
    local ps = self.projectiles
    ps[#ps + 1] = { x = x, y = y, dx = dx, dy = dy }
end

function GameLevel:burstCoconut(p)
    self.particles:emit(p.x + 3, p.y + 3, 6, {
        colors = {'b', 'n', 'W'}, speed = {30, 80}, upward = true,
        gravity = 400, life = {0.3, 0.5}, size = {1, 2},
    })
    gSounds['thud']:stop(); gSounds['thud']:play()
end

function GameLevel:updateProjectiles(dt)
    local ps = self.projectiles
    local tm = self.tileMap
    for i = #ps, 1, -1 do
        local p = ps[i]
        p.dy = math.min(p.dy + COCONUT_GRAVITY * dt, MAX_FALL_SPEED)
        p.x = p.x + p.dx * dt
        p.y = p.y + p.dy * dt
        if tm:isSolidAt(p.x + 3, p.y + 3) or tm:isWaterAt(p.x + 3, p.y + 3) then
            self:burstCoconut(p)
            swapRemove(ps, i)
        elseif p.y > self.height or p.x < -16 or p.x > self.width + 16 then
            swapRemove(ps, i)
        end
    end
end

---------------------------------------------------------------------------
-- DRAWING
---------------------------------------------------------------------------

-- camX, camY: whole-pixel camera position (for culling)
function GameLevel:render(camX, camY)
    self.tileMap:render(camX, camY)
    self:renderPlatforms(camX)

    local left, right = camX, camX + VIRTUAL_WIDTH
    local objects = self.objects
    for i = 1, #objects do
        local o = objects[i]
        if o.x + o.width >= left and o.x <= right then
            o:render()
        end
    end

    local enemies = self.enemies
    for i = 1, #enemies do
        local e = enemies[i]
        if e.x + e.width + 4 >= left and e.x - 4 <= right then
            e:render()
        end
    end

    -- coconuts in the air
    local ps = self.projectiles
    for i = 1, #ps do
        SpriteBuilder.draw('coconut', 1, ps[i].x, ps[i].y)
    end

    -- running timer plates: a bar above the plate that shrinks
    for _, g in pairs(self.gateGroups) do
        for i = 1, #g.plates do
            local p = g.plates[i]
            if p.duration and p.remaining > 0 and not p.pressed then
                local w = math.max(1, mfloor(14 * p.remaining / p.duration + 0.5))
                Palette.set('K')
                love.graphics.rectangle('fill', p.x, p.y + 6, 16, 4)
                Palette.set((p.remaining < TIMER_FAST_AT) and 'R' or 'Y')
                love.graphics.rectangle('fill', p.x + 1, p.y + 7, w, 2)
                love.graphics.setColor(1, 1, 1, 1)
            end
        end
    end
end

-- drawn after the ball so debris and sparkles appear on top
function GameLevel:renderEffects()
    self.particles:render()
end
