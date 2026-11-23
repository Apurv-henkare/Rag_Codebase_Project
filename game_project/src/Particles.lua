--[[
    Inflate - Particles
    A fixed pool of square pixel particles (no garbage created while playing).
    Used for: pop burst, block debris, gem sparkles, air puffs.

    particles:emit(x, y, count, {
        colors  = {'R', 'O'},     palette letters, picked at random
        speed   = {40, 120},      min / max speed (px/s)
        upward  = true,           only shoot into the upper half
        angle   = -math.pi / 2,   or: one direction (radians) ...
        spread  = 0.2,            ... +- this much
        gravity = 400,
        life    = {0.4, 0.8},     min / max seconds
        size    = {1, 2},         min / max square size in pixels
    })
]]

Particles = Class{}

local lg = love.graphics
local mrandom, mcos, msin, mfloor, mpi = math.random, math.cos, math.sin, math.floor, math.pi

local function rand(lo, hi) return lo + mrandom() * (hi - lo) end

function Particles:init(max)
    self.max = max or 200
    self.pool = {}
    for i = 1, self.max do
        self.pool[i] = { active = false, x = 0, y = 0, vx = 0, vy = 0,
                         life = 0, gravity = 0, size = 1, color = nil }
    end
    self.next = 1     -- round-robin slot (oldest particle is reused if full)
end

function Particles:emit(x, y, count, o)
    local colors = o.colors or {'W'}
    local speed = o.speed or {40, 120}
    local life = o.life or {0.4, 0.8}
    local size = o.size or {1, 2}
    for _ = 1, count do
        local p = self.pool[self.next]
        self.next = self.next % self.max + 1

        local angle
        if o.angle then          -- a direction (radians) +- spread
            angle = o.angle + rand(-1, 1) * (o.spread or 0)
        else
            angle = o.upward and rand(-mpi, 0) or rand(0, mpi * 2)
        end
        local spd = rand(speed[1], speed[2])
        p.active = true
        p.x, p.y = x, y
        p.vx, p.vy = mcos(angle) * spd, msin(angle) * spd
        p.gravity = o.gravity or 0
        p.life = rand(life[1], life[2])
        p.size = mrandom(size[1], size[2])
        p.color = Palette.get(colors[mrandom(#colors)])
    end
end

function Particles:update(dt)
    local pool = self.pool
    for i = 1, self.max do
        local p = pool[i]
        if p.active then
            p.life = p.life - dt
            if p.life <= 0 then
                p.active = false
            else
                p.vy = p.vy + p.gravity * dt
                p.x = p.x + p.vx * dt
                p.y = p.y + p.vy * dt
            end
        end
    end
end

function Particles:render()
    local pool = self.pool
    for i = 1, self.max do
        local p = pool[i]
        if p.active then
            local c = p.color
            lg.setColor(c[1], c[2], c[3], 1)
            lg.rectangle('fill', mfloor(p.x), mfloor(p.y), p.size, p.size)
        end
    end
    lg.setColor(1, 1, 1, 1)
end
