--[[
    Inflate - Enemy
    Enemies are Entities with their own states:

      crawler  spiky walker. 'patrol' -> 'stunned' (knocked over) -> 'squashed'
      buzzer   small flyer that bobs up and down. 'fly' -> 'squashed'
      shade    big cave creature (level 14). Can't be hurt. 'sleep' -> 'chase'
               (ball came close) -> 'return' (ball got away) -> 'sleep'.
               In the jungle it is the Stone Guardian (same behaviour).

    In 'crystal' levels the crawler and buzzer are smarter:
      crawler = crystal beetle: sees the ball on its floor, shakes, charges.
                'patrol' -> 'charge' -> 'stunned' (hit a wall) / 'patrol'
      buzzer  = cave bat: hangs from the ceiling, swoops at the ball passing
                below, flies back. 'hang' -> 'swoop' -> 'hang'

    Jungle creatures (level 15):
      frog     hops along, toward the ball when it sees it.     'hop'
      snake    hides in the grass, pops out and lunges.         'lurk'
      monkey   sits up high and throws coconuts at the ball.    'throw'
      bug      flying beetle: drifts, dives at the ball.        'drift' -> 'swoop'
      plant    snapper plant: bites when the ball comes close.  'snap'
               Can't be hurt. Only dangerous while biting.
      piranha  swims in a pool, leaps out at the ball above.    'swim'
               Can't be hurt.
    Frogs, snakes and monkeys can be knocked over like crawlers; everything
    that can be hurt is squashed by the Big ball landing on it.

    Position/size is the hitbox; the sprite is drawn with an offset.
    Sprites face right; direction -1 mirrors them.
]]

Enemy = Class{__includes = Entity}

-- w, h: hitbox. ox, oy: sprite offset. squash / stun: frame numbers.
-- wake: state after being knocked over. unkillable: never squashed.
local KINDS = {
    crawler = { w = 12, h = 12, ox = -2, oy = -3, sprite = 'crawler', squash = 4, stun = 3, wake = 'patrol' },
    buzzer  = { w = 12, h = 10, ox = -1, oy = -4, sprite = 'buzzer', squash = 3 },
    shade   = { w = 20, h = 28, ox = -2, oy = -4, sprite = 'shade', unkillable = true },
    frog    = { w = 12, h = 10, ox = -2, oy = -6, sprite = 'frog', squash = 5, stun = 4, wake = 'hop' },
    snake   = { w = 12, h = 11, ox = -2, oy = -5, sprite = 'snake', squash = 5, stun = 4, wake = 'lurk' },
    monkey  = { w = 12, h = 14, ox = -2, oy = -2, sprite = 'monkey', squash = 5, stun = 4, wake = 'throw' },
    bug     = { w = 12, h = 10, ox = -2, oy = -3, sprite = 'flybug', squash = 3 },
    plant   = { w = 12, h = 16, ox = -2, oy = -16, sprite = 'snapper', unkillable = true },
    piranha = { w = 12, h = 8,  ox = -2, oy = -2, sprite = 'piranha', unkillable = true },
}

-- the same enemies dressed for other themes (same frames, same behaviour)
local THEME_SPRITES = {
    factory = { crawler = 'sparkbot', buzzer = 'drone' },
    ruins   = { crawler = 'crab',     buzzer = 'jelly' },
    grove   = { crawler = 'hedgehog', buzzer = 'moth' },
    ice     = { crawler = 'penguin',  buzzer = 'owl' },
    space   = { crawler = 'slug',     buzzer = 'sparkstar' },
    crystal = { crawler = 'beetle',   buzzer = 'bat' },
    jungle  = { shade = 'guardian' },
}

-- where the big chasers' eyes are (sprite pixels, facing right) and their glow
local EYES = {
    shade    = { x = 18, y = 13, color = 'Y' },
    guardian = { x = 15, y = 6,  color = 'L' },
}

-- themes whose crawlers charge and whose flyers swoop
local SMART_THEMES = { crystal = true }

local mmin, mabs, msqrt, mceil, mfloor = math.min, math.abs, math.sqrt, math.ceil, math.floor

-- kind: see KINDS. (cellX, cellY): top-left of its level cell.
-- theme (optional): picks the look, e.g. robots in 'factory' levels
function Enemy:init(kind, tileMap, cellX, cellY, theme)
    local k = assert(KINDS[kind], 'Unknown enemy kind: ' .. tostring(kind))
    -- stand on the bottom of the cell, centred
    Entity.init(self, {
        x = cellX + (TILE_SIZE - k.w) / 2,
        y = cellY + TILE_SIZE - k.h,
        width = k.w, height = k.h,
    })
    self.kind = kind
    self.tileMap = tileMap
    local themed = THEME_SPRITES[theme or '']
    self.spriteName = (themed and themed[kind]) or k.sprite
    self.offsetX, self.offsetY = k.ox, k.oy
    self.smart = SMART_THEMES[theme or ''] or false
    self.unkillable = k.unkillable or false
    self.stunnable = k.stun ~= nil
    self.squashFrame = k.squash or 3
    self.stunFrame = k.stun or 3
    self.wakeState = k.wake or 'patrol'
    self.restState = 'hang'      -- where a swoop ends (bats hang, jungle bugs drift)
    self.reach = 0               -- px the hitbox reaches up (a biting plant)

    self.direction = -1          -- start walking / facing left (toward the player)
    self.grounded = false
    self.harmless = false        -- true while stunned or squashed
    self.squashed = false
    self.remove = false          -- GameLevel deletes the enemy when true
    self.frame = 1
    self.target = nil            -- the ball (set every update)
    self.level = nil             -- the GameLevel (set by GameLevel, for screen shake)

    -- smart enemies
    self.chargeCooldown = 0      -- beetle: rest after a charge
    self.swoopCooldown = 0       -- bat / bug: rest after a swoop
    self.shakeX = 0              -- beetle: shaking before a charge (drawing only)
    -- shade
    self.awake = false
    self.hitPause = 0            -- stands still a moment after hurting the ball
    self.safeSpots = {}          -- checkpoints it never walks up to (set by LevelMaker)

    if kind == 'crawler' then
        self.animation = Animation{ frames = {1, 2}, interval = 0.25 }
        self.stateMachine = StateMachine {
            ['patrol']   = function() return EnemyPatrolState(self) end,
            ['charge']   = function() return EnemyChargeState(self) end,
            ['stunned']  = function() return EnemyStunnedState(self) end,
            ['squashed'] = function() return EnemySquashedState(self) end,
        }
        self:setHome()
        self:changeState('patrol')
    elseif kind == 'shade' then
        self.animation = Animation{ frames = {2, 3}, interval = 0.18 }
        self.stateMachine = StateMachine {
            ['sleep']  = function() return EnemySleepState(self) end,
            ['chase']  = function() return EnemyChaseState(self) end,
            ['return'] = function() return EnemyReturnState(self) end,
        }
        self:setHome()
        self:changeState('sleep')
    elseif kind == 'frog' then
        self.stateMachine = StateMachine {
            ['hop']      = function() return EnemyHopState(self) end,
            ['stunned']  = function() return EnemyStunnedState(self) end,
            ['squashed'] = function() return EnemySquashedState(self) end,
        }
        self:changeState('hop')
    elseif kind == 'snake' then
        self.stateMachine = StateMachine {
            ['lurk']     = function() return EnemyLurkState(self) end,
            ['stunned']  = function() return EnemyStunnedState(self) end,
            ['squashed'] = function() return EnemySquashedState(self) end,
        }
        self:changeState('lurk')
    elseif kind == 'monkey' then
        self.stateMachine = StateMachine {
            ['throw']    = function() return EnemyThrowState(self) end,
            ['stunned']  = function() return EnemyStunnedState(self) end,
            ['squashed'] = function() return EnemySquashedState(self) end,
        }
        self:changeState('throw')
    elseif kind == 'bug' then
        self.animation = Animation{ frames = {1, 2}, interval = 0.07 }
        self.restState = 'drift'
        self.driftX, self.driftY = self.x, self.y - 6
        self.stateMachine = StateMachine {
            ['drift']    = function() return EnemyDriftState(self) end,
            ['swoop']    = function() return EnemySwoopState(self) end,
            ['squashed'] = function() return EnemySquashedState(self) end,
        }
        self:changeState('drift')
    elseif kind == 'plant' then
        self.stateMachine = StateMachine {
            ['snap'] = function() return EnemySnapState(self) end,
        }
        self:changeState('snap')
    elseif kind == 'piranha' then
        self.animation = Animation{ frames = {1, 2}, interval = 0.2 }
        self:setHome()
        self.stateMachine = StateMachine {
            ['swim'] = function() return EnemySwimState(self) end,
        }
        self:changeState('swim')
    elseif self.smart then
        -- bat: hangs from the ceiling above its cell
        self.animation = Animation{ frames = {1, 2}, interval = 0.08 }
        self.stateMachine = StateMachine {
            ['hang']     = function() return EnemyHangState(self) end,
            ['swoop']    = function() return EnemySwoopState(self) end,
            ['squashed'] = function() return EnemySquashedState(self) end,
        }
        local col = mfloor((cellX + TILE_SIZE / 2) / TILE_SIZE) + 1
        local row = mfloor(cellY / TILE_SIZE) + 1
        for r = row, math.max(2, row - 8), -1 do
            local t = tileMap:getTile(col, r - 1)
            if t and t.solid then
                self.y = (r - 1) * TILE_SIZE      -- hitbox top touches the ceiling
                break
            end
        end
        self:setHome()
        self:changeState('hang')
    else
        self.animation = Animation{ frames = {1, 2}, interval = 0.06 }
        self.stateMachine = StateMachine {
            ['fly']      = function() return EnemyFlyState(self) end,
            ['squashed'] = function() return EnemySquashedState(self) end,
        }
        self:changeState('fly')
    end
end

function Enemy:setHome()
    self.homeX, self.homeY = self.x, self.y
end

function Enemy:update(dt, ball)
    self.target = ball
    Entity.update(self, dt)
    -- fell out of the level (e.g. the floor under it was smashed)
    if self.y > self.tileMap.height + 48 then self.remove = true end
end

-- gravity + vertical tile collision (walkers only)
function Enemy:applyGravity(dt)
    self.dy = mmin(self.dy + GRAVITY * dt, MAX_FALL_SPEED)
    local newY, hit = self.tileMap:sweepY(self.x, self.y, self.width, self.height, self.dy * dt)
    self.y = newY
    if hit then
        if self.dy > 0 then self.grounded = true end
        self.dy = 0
    else
        self.grounded = false
    end
end

-- can this enemy see the ball? (closer than maxDist, no solid tile in between)
function Enemy:canSee(ball, maxDist)
    if not ball or ball.dead then return false end
    local x0, y0 = self:centerX(), self.y + 6
    local dx, dy = ball:centerX() - x0, ball:centerY() - y0
    local d = msqrt(dx * dx + dy * dy)
    if d > maxDist then return false end
    local steps = mceil(d / 4)
    local tm = self.tileMap
    for i = 1, steps - 1 do
        local t = i / steps
        if tm:isSolidAt(x0 + dx * t, y0 + dy * t) then return false end
    end
    return true
end

-- is the ball within this distance (sounds only play for enemies near the ball)
function Enemy:nearBall(dist)
    local ball = self.target
    if not ball or ball.dead then return false end
    return mabs(ball:centerX() - self:centerX()) < dist and mabs(ball:centerY() - self:centerY()) < dist
end

-- beetle: is the ball on the same floor, close, in plain sight?
function Enemy:seesOnFloor(ball, sight)
    sight = sight or BEETLE_SIGHT
    if not ball or ball.dead then return false end
    if mabs(ball:bottom() - self:bottom()) > 12 then return false end
    if mabs(ball:centerX() - self:centerX()) > sight then return false end
    return self:canSee(ball, sight + 24)
end

-- walking things: is there floor to stand on at x (the bottom-front corner)?
function Enemy:floorAhead(frontX)
    return self.tileMap:isSolidAt(frontX, self.y + self.height + 1)
end

-- shade: would stepping to newX bring it up to a checkpoint? (it never goes there)
function Enemy:intoSafeZone(newX)
    local spots = self.safeSpots
    local cx, bottom = self:centerX(), self:bottom()
    local newCX = newX + self.width / 2
    for i = 1, #spots do
        local s = spots[i]
        if mabs(bottom - s.y) < SHADE_SAFE_Y then
            local after = mabs(newCX - s.x)
            if after < SHADE_SAFE_X and after < mabs(cx - s.x) then return true end
        end
    end
    return false
end

-- shade: walk sideways by dx. Stops at walls, ledges (it can't jump or fall)
-- and checkpoints. Returns false when it couldn't move.
function Enemy:walk(dt)
    if self.dx == 0 then return true end
    local tm = self.tileMap
    local dir = self.dx > 0 and 1 or -1
    local newX, wall = tm:sweepX(self.x, self.y, self.width, self.height, self.dx * dt)
    if wall or newX < 0 or newX > tm.width - self.width then
        self.dx = 0
        return false
    end
    local frontX = dir > 0 and (newX + self.width + 1) or (newX - 1)
    if self.grounded and not tm:isSolidAt(frontX, self.y + self.height + 1) then
        self.dx = 0
        return false
    end
    if self:intoSafeZone(newX) then
        self.dx = 0
        return false
    end
    self.x = newX
    return true
end

-- shade: back to its spot, asleep (the ball popped)
function Enemy:goHome()
    self.x, self.y = self.homeX, self.homeY
    self.dx, self.dy = 0, 0
    self:changeState('sleep')
end

-- knocked over by the Big ball; dir = direction it gets pushed
function Enemy:stun(dir)
    if not self.stunnable or self.squashed then return end
    self:changeState('stunned', { dir = dir })
end

function Enemy:squash()
    if self.squashed or self.unkillable then return end
    self.reach = 0
    self:changeState('squashed')
end

function Enemy:render()
    local flip = self.direction < 0
    local ox = self.offsetX
    local _, _, spriteW = gFrames[self.spriteName][self.frame]:getViewport()
    if flip then
        -- mirror the offset too, so the sprite stays lined up with the hitbox
        ox = -(spriteW - self.width + self.offsetX)
    end
    local sx, sy = self.x + ox + self.shakeX, self.y + self.offsetY

    -- a big chaser's eyes glow while it is awake (red while it roars)
    local eyes = EYES[self.spriteName]
    if eyes and self.awake then
        local ex = flip and (sx + spriteW - eyes.x) or (sx + eyes.x)
        local color = (self.frame == 4) and 'R' or eyes.color
        Palette.set(color, 0.14)
        love.graphics.circle('fill', ex, sy + eyes.y, 10)
        Palette.set(color, 0.12)
        love.graphics.circle('fill', ex, sy + eyes.y, 5)
        love.graphics.setColor(1, 1, 1, 1)
    end

    SpriteBuilder.draw(self.spriteName, self.frame, sx, sy, flip)
end
