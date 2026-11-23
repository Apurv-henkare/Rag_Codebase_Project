--[[
    Inflate - GameObject
    Anything placed in a level that isn't a tile: pumps, gems, goal flag,
    checkpoints, springs and keys.

    GameObject{ type, x, y, width, height, sprite, animation, hitbox }
      hitbox = {x, y, w, h} relative to the object (default: the whole sprite)
]]

GameObject = Class{}

function GameObject:init(def)
    self.type = def.type
    self.x = def.x
    self.y = def.y
    self.width = def.width
    self.height = def.height
    self.sprite = def.sprite
    self.animation = def.animation   -- optional Animation
    self.frame = def.frame or 1      -- used when there is no animation
    self.hitbox = def.hitbox

    -- pump / spring state
    self.pressTimer = 0
    self.cooldown = 0
    -- checkpoint state
    self.active = false
    -- pressure plate state (group: which gates, duration: timer plates only)
    self.group = def.group
    self.duration = def.duration
    self.pressed = false           -- Big ball on it right now
    self.remaining = 0             -- timer plates: seconds left / hold plates: grace left
    self.tick = 0
    -- gravity orb: dir -1 up / 1 down; lit = touching it would flip the ball now
    self.dir = def.dir
    -- crystal cluster / jungle decoration: colour of its glow (nil = none)
    self.glow = def.glow
    self.lit = true
    -- for bobbing (key); offset by position so keys don't bob in sync
    self.time = (self.x * 0.05) % 1
end

function GameObject:getHitbox()
    local hb = self.hitbox
    if hb then
        return self.x + hb[1], self.y + hb[2], hb[3], hb[4]
    end
    return self.x, self.y, self.width, self.height
end

function GameObject:update(dt)
    if self.animation then
        self.animation:update(dt)
    end
    if self.pressTimer > 0 then self.pressTimer = self.pressTimer - dt end
    if self.cooldown > 0 then self.cooldown = self.cooldown - dt end
    self.time = self.time + dt
end

function GameObject:render()
    local frame = self.frame
    if self.animation then
        frame = self.animation:getCurrentFrame()
    elseif self.type == 'pump' or self.type == 'spring' then
        frame = self.pressTimer > 0 and 2 or 1    -- pump handle down / spring extended
    elseif self.type == 'checkpoint' then
        frame = self.active and 2 or 1
    elseif self.type == 'plate' then
        frame = self.pressed and 2 or 1
    elseif self.type == 'lantern' then
        -- warm glow: two see-through pixel circles that flicker a little
        local flicker = (math.sin(self.time * 7) + math.sin(self.time * 11.3)) * 0.015
        Palette.set('O', 0.10 + flicker)
        love.graphics.circle('fill', self.x + 8, self.y + 7, 20)
        Palette.set('Y', 0.12 + flicker)
        love.graphics.circle('fill', self.x + 8, self.y + 7, 11)
        love.graphics.setColor(1, 1, 1, 1)
    elseif self.type == 'crystal' and self.glow then
        -- soft glow in the crystal's colour, slowly breathing
        local pulse = math.sin(self.time * 1.7) * 0.025
        Palette.set(self.glow, 0.08 + pulse)
        love.graphics.circle('fill', self.x + 8, self.y + 10, 18)
        Palette.set(self.glow, 0.12 + pulse)
        love.graphics.circle('fill', self.x + 8, self.y + 10, 9)
        love.graphics.setColor(1, 1, 1, 1)
    end

    if self.type == 'orb' then
        -- soft glow; orbs that would do nothing right now are dimmed
        local pulse = math.sin(self.time * 4) * 0.03
        Palette.set(self.dir < 0 and 'C' or 'Y', (self.lit and 0.16 or 0.05) + pulse)
        love.graphics.circle('fill', self.x + 8, self.y + 8, 10)
        love.graphics.setColor(1, 1, 1, self.lit and 1 or 0.4)
    end

    local y = self.y
    if self.type == 'key' then
        -- whole-pixel bob: 0, -1, -2, -1 ...
        local step = math.floor(self.time * 4) % 4
        y = y - (step == 2 and 2 or (step % 2))
    end
    SpriteBuilder.draw(self.sprite, frame, self.x, y)
    if self.type == 'orb' then love.graphics.setColor(1, 1, 1, 1) end
end
