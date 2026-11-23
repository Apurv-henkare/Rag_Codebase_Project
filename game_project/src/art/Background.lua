--[[
    Inflate - Background
    Generated pixel backgrounds, built once into images; drawing just offsets
    them (parallax). Two themes:

      sky   dithered sky, drifting clouds, two hill layers
      cave  dark cave with stalactites / stalagmites (layers repeat vertically)
      ruins    deep teal: old columns and arches, rising bubbles, sea plants
      grove    dusk forest: dark trees, hanging lanterns, blinking fireflies
      ice      night: twinkling stars, a moving aurora, snowy peaks, pines,
               falling snow
      space    stars, a see-through nebula, a ringed planet, floating asteroids
      crystal  a dark cavern with giant purple / silver crystals far away,
               bright crystal clusters on the near rocks, twinkling sparkles
      jungle   sunny sky with clouds and birds, tall green cliffs with
               moving waterfalls and mist, a canopy of trees and palms
      factory  dark hall: far pipes with slowly turning giant fans, near
               copper pipes with valves and gauges (layers repeat vertically)

    Background.render(cameraX, time, cameraY, levelHeight, theme)
      cameraY / levelHeight are optional: with them the layers also move
      vertically, so climbing a tall level feels like going up.
]]

Background = {}

local LAYER_W = 640           -- layers wrap every 640px (seamless)
local TWO_PI = math.pi * 2
local mabs, mfloor, mmax = math.abs, math.floor, math.max

-- 4x4 Bayer matrix, thresholds 0..1, used for ordered dithering
local BAYER = {
    { 0,  8,  2, 10},
    {12,  4, 14,  6},
    { 3, 11,  1,  9},
    {15,  7, 13,  5},
}
local function bayer(x, y)
    return (BAYER[y % 4 + 1][x % 4 + 1] + 0.5) / 16
end

local function setPal(data, x, y, letter)
    local c = Palette.get(letter)
    data:setPixel(x, y, c[1], c[2], c[3], 1)
end

local function toImage(data, wrapY)
    local img = love.graphics.newImage(data)
    img:setFilter('nearest', 'nearest')
    img:setWrap('repeat', wrapY and 'repeat' or 'clamp')
    return img
end

-- vertical gradient: solid top colour, short dithered seam, solid bottom colour
local function buildGradient(top, bottom, seamTop, seamBottom)
    local w, h = BASE_WIDTH, BASE_HEIGHT     -- 320 wide: the 4px dither repeats seamlessly
    local data = love.image.newImageData(w, h)
    for y = 0, h - 1 do
        local t = (y - seamTop) / (seamBottom - seamTop)
        for x = 0, w - 1 do
            setPal(data, x, y, (t > bayer(x, y)) and bottom or top)
        end
    end
    return toImage(data)
end

-- seamless ridge: sum of sines whose periods divide LAYER_W
local function ridge(x, base, waves)
    local y = base
    for i = 1, #waves do
        local wv = waves[i]
        y = y + wv[1] * math.sin(TWO_PI * wv[2] * x / LAYER_W + wv[3])
    end
    return mfloor(y + 0.5)
end

-- spiky profile (for stalactites): sum of |sin|^power bumps
local function spikes(x, base, waves)
    local y = base
    for i = 1, #waves do
        local wv = waves[i]   -- {amplitude, frequency, phase, power}
        y = y + wv[1] * mabs(math.sin(TWO_PI * wv[2] * x / LAYER_W + wv[3])) ^ wv[4]
    end
    return mfloor(y + 0.5)
end

-- hills: body colour, 1px rim on top, optional dither into a darker colour near the bottom
local function buildHills(base, waves, body, rim, dark, darkFrom)
    local h = BASE_HEIGHT
    local data = love.image.newImageData(LAYER_W, h)
    for x = 0, LAYER_W - 1 do
        local top = ridge(x, base, waves)
        for y = mmax(0, top), h - 1 do
            local letter = body
            if y == top then
                letter = rim
            elseif dark and y >= darkFrom then
                local t = (y - darkFrom) / (h - darkFrom) * 1.6
                if t > bayer(x, y) then letter = dark end
            end
            setPal(data, x, y, letter)
        end
    end
    return toImage(data)
end

-- clouds: unions of pixel circles, white top, light slate underside
local function buildClouds()
    local h = 70
    local data = love.image.newImageData(LAYER_W, h)
    local rng = love.math.newRandomGenerator(7)
    local blobs = {}
    for c = 0, 5 do
        local cx = c * (LAYER_W / 6) + rng:random(0, 50)
        local cy = rng:random(18, 48)
        local n = rng:random(3, 5)
        for i = 1, n do
            blobs[#blobs + 1] = {
                cx + (i - (n + 1) / 2) * rng:random(7, 10),
                cy + rng:random(-3, 2),
                rng:random(6, 11),
            }
        end
    end
    local function inside(x, y)
        for i = 1, #blobs do
            local b = blobs[i]
            local dx = mabs(x - b[1]); dx = math.min(dx, LAYER_W - dx)
            local dy = (y - b[2]) * 1.6       -- flatter clouds
            if dx * dx + dy * dy <= b[3] * b[3] then return true end
        end
        return false
    end
    for y = 0, h - 1 do
        for x = 0, LAYER_W - 1 do
            if inside(x, y) then
                setPal(data, x, y, inside(x, y + 2) and 'W' or 'g')
            end
        end
    end
    return toImage(data)
end

-- cave layer: stalactites hanging from the top and rocks rising from the bottom.
-- Repeats vertically, so deep levels show layer after layer of cave.
local function buildCaveLayer(topWaves, topBase, bottomWaves, bottomBase, body, rim)
    local h = BASE_HEIGHT
    local data = love.image.newImageData(LAYER_W, h)
    for x = 0, LAYER_W - 1 do
        local hang = spikes(x, topBase, topWaves)          -- stalactite length
        for y = 0, math.min(h - 1, hang) do
            setPal(data, x, y, (y == hang) and rim or body)
        end
        local rise = h - spikes(x, bottomBase, bottomWaves) -- stalagmite top
        for y = mmax(0, rise), h - 1 do
            setPal(data, x, y, (y == rise) and rim or body)
        end
    end
    return toImage(data, true)
end

---------------------------------------------------------------------------
-- FACTORY
---------------------------------------------------------------------------

local function fillRect(data, x, y, w, h, letter)
    local dw, dh = data:getWidth(), data:getHeight()
    for py = mmax(0, y), math.min(dh - 1, y + h - 1) do
        for px = x, x + w - 1 do
            setPal(data, px % dw, py, letter)       -- wraps sideways (seamless)
        end
    end
end

-- a pipe: body with a light edge on the top / left and a dark edge bottom / right
local function vPipe(data, x, w, body, light, dark)
    fillRect(data, x, 0, w, data:getHeight(), body)
    fillRect(data, x + 1, 0, 1, data:getHeight(), light)
    fillRect(data, x + w - 1, 0, 1, data:getHeight(), dark)
end
local function hPipe(data, y, h, body, light, dark)
    fillRect(data, 0, y, LAYER_W, h, body)
    fillRect(data, 0, y + 1, LAYER_W, 1, light)
    fillRect(data, 0, y + h - 1, LAYER_W, 1, dark)
end

-- filled pixel circle, calls paint(x, y, dist) for every pixel inside
local function circle(data, cx, cy, r, paint)
    for y = cy - r, cy + r do
        for x = cx - r, cx + r do
            local dx, dy = x + 0.5 - cx, y + 0.5 - cy
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist <= r and y >= 0 and y < data:getHeight() then
                local letter = paint(dist, math.atan2(dy, dx))
                if letter then setPal(data, x % LAYER_W, y, letter) end
            end
        end
    end
end

-- giant 3-blade fan in a round housing
local function bigFan(data, cx, cy, r, angle)
    circle(data, cx, cy, r, function(dist, a)
        if dist > r - 2 then return 'd' end                 -- housing ring
        if dist <= r * 0.16 then return 'g' end             -- hub
        for k = 0, 2 do
            local d = (a - angle - k * TWO_PI / 3) % TWO_PI
            if d > math.pi then d = TWO_PI - d end
            if d < 0.42 then return (d < 0.3) and 'D' or 'd' end
        end
        return 'K'
    end)
end

-- far layer: steel pipes + giant fans. One image per fan angle (animation)
local function buildFactoryFar(angle)
    local data = love.image.newImageData(LAYER_W, BASE_HEIGHT)
    hPipe(data, 34, 10, 'D', 'd', 'K')
    hPipe(data, 128, 8, 'D', 'd', 'K')
    for _, p in ipairs({{24, 12}, {196, 8}, {300, 16}, {470, 10}, {560, 8}}) do
        vPipe(data, p[1], p[2], 'D', 'd', 'K')
    end
    -- flanges on the horizontal pipes
    for x = 0, LAYER_W - 1, 80 do
        fillRect(data, x + 40, 32, 3, 14, 'd')
        fillRect(data, x + 10, 126, 3, 12, 'd')
    end
    bigFan(data, 110, 82, 30, angle)
    bigFan(data, 400, 70, 24, -angle)
    bigFan(data, 600, 150, 16, angle * 1.5)
    return toImage(data, true)
end

-- near layer: copper pipes with valve wheels and pressure gauges
local function buildFactoryNear()
    local data = love.image.newImageData(LAYER_W, BASE_HEIGHT)
    for _, p in ipairs({{70, 10}, {372, 8}, {520, 12}}) do
        vPipe(data, p[1], p[2], 'b', 'n', 'K')
    end
    hPipe(data, 96, 8, 'b', 'n', 'K')
    -- valve wheels where pipes cross
    for _, x in ipairs({75, 376, 526}) do
        circle(data, x, 100, 7, function(dist)
            if dist > 5.5 then return 'K' end
            if dist > 4 then return 'O' end
            if dist < 1.5 then return 'Y' end
            return nil
        end)
    end
    -- gauges: grey face, dark rim, red needle
    for _, g in ipairs({{75, 40, 0.6}, {376, 150, 2.2}, {526, 30, 1.4}}) do
        local gx, gy, needle = g[1], g[2], g[3]
        circle(data, gx, gy, 8, function(dist, a)
            if dist > 6.5 then return 'K' end
            local d = (a - needle) % TWO_PI
            if d > math.pi then d = TWO_PI - d end
            if d < 0.3 and dist < 5.5 then return 'R' end
            if dist < 1.2 then return 'K' end
            return 'g'
        end)
    end
    return toImage(data, true)
end

---------------------------------------------------------------------------
-- RUINS (sunken gardens)
---------------------------------------------------------------------------

-- far layer: old columns joined by arches (dark stone on deep teal)
local function buildRuinsFar()
    local data = love.image.newImageData(LAYER_W, BASE_HEIGHT)
    local cols = {40, 150, 260, 380, 500, 600}
    for i, x in ipairs(cols) do
        vPipe(data, x, 14, 'D', 'd', 'K')
        fillRect(data, x - 3, 26, 20, 5, 'd')          -- capital
        fillRect(data, x - 3, 31, 20, 2, 'D')
        fillRect(data, x - 3, 150, 20, 4, 'd')         -- base
        -- a broken column every other time: a gap with rubble
        if i % 2 == 0 then
            fillRect(data, x, 70, 14, 22, 'T')
            fillRect(data, x + 2, 88, 4, 4, 'D')
            fillRect(data, x + 8, 86, 3, 6, 'D')
        end
        -- arch to the next column
        local nx = cols[i % #cols + 1]
        if nx < x then nx = nx + LAYER_W end
        local cx, r = (x + 14 + nx) / 2, (nx - x - 14) / 2
        circle(data, mfloor(cx), 33, mfloor(r), function(dist, a)
            if a < 0 and dist > r - 6 then return (dist > r - 1) and 'd' or 'D' end
            return nil
        end)
    end
    return toImage(data, true)
end

-- near layer: tall swaying sea plants with glowing tips and spores
local function buildRuinsNear()
    local data = love.image.newImageData(LAYER_W, BASE_HEIGHT)
    local rng = love.math.newRandomGenerator(11)
    for _, x0 in ipairs({30, 120, 215, 330, 410, 470, 560}) do
        local k = rng:random(1, 3)                     -- whole waves per picture: seamless
        local phase = rng:random() * TWO_PI
        for y = 0, BASE_HEIGHT - 1 do
            local x = x0 + mfloor(3 * math.sin(TWO_PI * k * y / BASE_HEIGHT + phase) + 0.5)
            setPal(data, x % LAYER_W, y, 'L')
            setPal(data, (x + 1) % LAYER_W, y, 'G')
            setPal(data, (x + 2) % LAYER_W, y, 'T')
            if y % 22 == 0 then                        -- leaves
                fillRect(data, x + 3, y, 4, 2, 'G')
                fillRect(data, x - 3, y + 9, 3, 2, 'G')
            end
        end
    end
    for _ = 1, 40 do                                   -- glowing spores
        setPal(data, rng:random(0, LAYER_W - 1), rng:random(0, BASE_HEIGHT - 1), 'L')
    end
    return toImage(data, true)
end

-- rising bubbles (drawn moving up over the far layer)
local function buildBubbles()
    local data = love.image.newImageData(LAYER_W, BASE_HEIGHT)
    local rng = love.math.newRandomGenerator(5)
    for _ = 1, 26 do
        local bx, by = rng:random(4, LAYER_W - 5), rng:random(4, BASE_HEIGHT - 5)
        if rng:random() < 0.5 then
            setPal(data, bx, by, 'C')                  -- tiny bubble
        else
            for _, p in ipairs({{0, -1}, {-1, 0}, {1, 0}, {0, 1}}) do
                setPal(data, bx + p[1], by + p[2], 'C')
            end
            setPal(data, bx - 1, by - 1, 'W')          -- shine
        end
    end
    return toImage(data, true)
end

---------------------------------------------------------------------------
-- GROVE (lantern grove): dusk forest, hanging lanterns, fireflies
---------------------------------------------------------------------------

-- 3-colour gradient: top, middle, bottom with two dithered seams
local function buildGradient3(top, mid, bottom, s1a, s1b, s2a, s2b)
    local w, h = BASE_WIDTH, BASE_HEIGHT
    local data = love.image.newImageData(w, h)
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local b = bayer(x, y)
            local letter
            if y < s2a then
                letter = ((y - s1a) / (s1b - s1a) > b) and mid or top
            else
                letter = ((y - s2a) / (s2b - s2a) > b) and bottom or mid
            end
            setPal(data, x, y, letter)
        end
    end
    return toImage(data)
end

-- see-through pixel (for the soft lantern halos)
local function setPalA(data, x, y, letter, a)
    if y < 0 or y >= data:getHeight() then return end
    local c = Palette.get(letter)
    data:setPixel(x % data:getWidth(), y, c[1], c[2], c[3], a)
end

-- far layer: dark tree trunks with branches and leaf clumps
local function buildGroveFar()
    local data = love.image.newImageData(LAYER_W, BASE_HEIGHT)
    local rng = love.math.newRandomGenerator(23)
    for _, t in ipairs({{20, 16}, {130, 10}, {215, 20}, {340, 12}, {430, 18}, {545, 14}}) do
        local x, w = t[1], t[2]
        vPipe(data, x, w, 'K', 'b', 'K')
        -- two branches each side, going up and out
        for _, br in ipairs({{40, -1}, {95, 1}, {130, -1}, {60, 1}}) do
            local y0, dir = br[1], br[2]
            local sx = (dir < 0) and x or (x + w - 1)
            for i = 0, 26 do
                fillRect(data, sx + dir * i, y0 - mfloor(i * 0.6), 2, 3, 'K')
            end
            local lx, ly = sx + dir * 30, y0 - 18
            circle(data, lx, ly, 9 + rng:random(0, 4), function(dist)
                return (dist > 7) and 'D' or 'K'
            end)
        end
    end
    return toImage(data, true)
end

-- near layer: hanging lanterns with soft halos, and a few hanging vines
local function buildGroveNear()
    local data = love.image.newImageData(LAYER_W, BASE_HEIGHT)
    for _, v in ipairs({{60, 70}, {250, 40}, {395, 95}, {500, 55}, {610, 30}}) do
        local x, len = v[1], v[2]
        for y = 0, len do
            setPal(data, x + ((y % 12 < 6) and 0 or 1), y, 'T')
            if y % 9 == 4 then setPal(data, x + 2, y, 'G'); setPal(data, x - 1, y + 1, 'G') end
        end
    end
    for _, l in ipairs({{100, 50}, {175, 85}, {300, 40}, {455, 70}, {580, 100}}) do
        local x, ly = l[1], l[2]
        for y = 0, ly - 4 do setPal(data, x, y, 'K') end     -- string
        -- halo first, the lantern on top
        for dy = -14, 14 do
            for dx = -14, 14 do
                local d = math.sqrt(dx * dx + dy * dy)
                if d <= 14 and d > 4 then
                    local a = (d < 8) and 0.22 or 0.10
                    if (dx + dy) % 2 == 0 or d < 8 then setPalA(data, x + dx, ly + 2 + dy, 'O', a) end
                end
            end
        end
        fillRect(data, x - 2, ly - 3, 5, 1, 'K')
        fillRect(data, x - 3, ly - 2, 7, 8, 'R')
        fillRect(data, x - 2, ly - 1, 5, 6, 'O')
        fillRect(data, x - 1, ly, 3, 4, 'Y')
        fillRect(data, x - 2, ly + 6, 5, 1, 'K')
        setPal(data, x, ly + 7, 'R')
    end
    return toImage(data, true)
end

---------------------------------------------------------------------------
-- ICE (frostpeak): night sky, aurora, snowy peaks, pine trees
---------------------------------------------------------------------------

-- aurora: wavy see-through curtains of green and cyan (drifts sideways)
local function buildAurora()
    local data = love.image.newImageData(LAYER_W, BASE_HEIGHT)
    for x = 0, LAYER_W - 1 do
        local u = TWO_PI * x / LAYER_W                       -- whole waves: seamless
        local curtain = 0.6 + 0.4 * math.sin(u * 13)         -- vertical streaks
        local bands = {
            { 42 + 14 * math.sin(u * 2 + 0.5) + 6 * math.sin(u * 5), 12, 'L', 'C', 0.30 },
            { 70 + 10 * math.sin(u * 3 + 2.0) + 4 * math.sin(u * 7), 7, 'G', 'T', 0.22 },
        }
        for _, b in ipairs(bands) do
            local cy, half, inner, outer, strength = b[1], b[2], b[3], b[4], b[5]
            for dy = -half, half * 2 do
                local y = mfloor(cy + dy)
                if y >= 0 and y < BASE_HEIGHT then
                    -- bright bottom edge, a long fade upward
                    local f = (dy <= 0) and (1 + dy / half) or (1 - dy / (half * 2))
                    f = f * curtain * strength
                    if f > 0.02 then
                        local c = Palette.get((dy > -half / 3 and dy < half / 2) and inner or outer)
                        data:setPixel(x, y, c[1], c[2], c[3], f)
                    end
                end
            end
        end
    end
    return toImage(data)
end

-- far layer: sharp mountain peaks with snow caps, lit from the left
local function buildMountains()
    local data = love.image.newImageData(LAYER_W, BASE_HEIGHT)
    local peaks = {{40, 70}, {150, 95}, {235, 60}, {330, 85}, {440, 55}, {540, 90}}
    for x = 0, LAYER_W - 1 do
        local top, side = BASE_HEIGHT, 0
        for _, pk in ipairs(peaks) do
            for _, off in ipairs({-LAYER_W, 0, LAYER_W}) do        -- wrap around
                local dx = x - (pk[1] + off)
                local y = pk[2] + mabs(dx) * 0.9
                if y < top then top, side = y, dx end
            end
        end
        top = mfloor(top)
        for y = top, BASE_HEIGHT - 1 do
            local depth = y - top
            local letter = (side < 0) and 'd' or 'D'               -- lit side / shadow side
            if depth < 10 and (y < 115 or depth < 3) then
                letter = (side < 0) and 'W' or 'g'                 -- snow cap
            elseif depth < 14 and bayer(x, y) < 0.5 and y < 115 then
                letter = (side < 0) and 'g' or 'd'
            end
            setPal(data, x, y, letter)
        end
    end
    return toImage(data)
end

-- near layer: dark pines with snow on their branches, snowy ground
local function buildPines()
    local data = love.image.newImageData(LAYER_W, BASE_HEIGHT)
    local base = 168
    for _, t in ipairs({{30, 50}, {95, 38}, {170, 60}, {260, 44}, {330, 56}, {420, 40}, {500, 62}, {590, 46}}) do
        local cx, h = t[1], t[2]
        local top = base - h
        for y = top, base - 6 do
            local f = (y - top) / h
            local half = mfloor(2 + f * h * 0.38)
            if (y - top) % 9 == 8 then half = half - 3 end        -- branch layers
            for dx = -half, half do
                local letter = 'K'
                if dx == -half or dx == -half + 1 then
                    letter = ((y - top) % 9 < 2) and 'W' or 'D'   -- snow on the branch tops
                end
                setPal(data, (cx + dx) % LAYER_W, y, letter)
            end
        end
        fillRect(data, cx - 1, base - 6, 3, 6, 'b')                -- trunk
    end
    fillRect(data, 0, base, LAYER_W, BASE_HEIGHT - base, 'W')        -- snowy ground
    for x = 0, LAYER_W - 1, 7 do setPal(data, x, base, 'g') end
    return toImage(data)
end

---------------------------------------------------------------------------
-- SPACE (starfall): nebula, ringed planet, moon, floating asteroids
---------------------------------------------------------------------------

-- far layer: see-through nebula clouds, a ringed planet and a small moon
local function buildSpaceFar()
    local data = love.image.newImageData(LAYER_W, BASE_HEIGHT)
    -- nebula (whole waves sideways: seamless)
    for y = 0, BASE_HEIGHT - 1 do
        for x = 0, LAYER_W - 1 do
            local u = TWO_PI * x / LAYER_W
            local n = math.sin(u * 3 + math.sin(y * 0.05) * 1.5) * math.sin(y * 0.04 + u * 2)
            if n > 0.5 then
                setPalA(data, x, y, 'r', (n - 0.5) * 0.7)
            elseif n < -0.6 then
                setPalA(data, x, y, 'T', (-n - 0.6) * 0.8)
            end
        end
    end

    -- ringed planet: the back half of the ring, the planet, then the front half
    local px, py, r = 470, 80, 28
    local function ring(front)
        for y = py - 20, py + 20 do
            for x = px - 64, px + 64 do
                local dx, dy = x - px, y - py
                local t = dy - dx * 0.22                     -- tilted
                local e = (dx / (r * 2.1)) ^ 2 + (t / (r * 0.42)) ^ 2
                if e >= 0.62 and e <= 1 and ((t > 0) == front) then
                    local inside = dx * dx + dy * dy <= r * r
                    if front or not inside then
                        setPal(data, x % LAYER_W, y, (e < 0.8) and 'Y' or 'n')
                    end
                end
            end
        end
    end
    ring(false)
    circle(data, px, py, r, function(dist, a)
        local dx, dy = math.cos(a) * dist, math.sin(a) * dist
        local band = mfloor((dy + r) / 6) % 3
        local letter = (band == 0) and 'Y' or ((band == 1) and 'O' or 'R')
        local shade = (dx + dy * 0.4) / r                    -- lit from the top-left
        if shade > 0.55 then letter = 'r'
        elseif shade > 0.3 then letter = (bayer(mfloor(px + dx), mfloor(py + dy)) < 0.5) and 'r' or letter end
        return letter
    end)
    ring(true)

    -- small grey moon with craters
    circle(data, 140, 46, 9, function(dist, a)
        local dx = math.cos(a) * dist
        if dx > 4 then return 'd' end
        return 'g'
    end)
    for _, c in ipairs({{137, 43}, {142, 49}, {139, 48}}) do setPal(data, c[1], c[2], 'd') end
    return toImage(data)
end

-- near layer: floating asteroids, one with a little observatory on it
local function buildSpaceNear()
    local data = love.image.newImageData(LAYER_W, BASE_HEIGHT)
    for _, rk in ipairs({{70, 150, 18, 0.3}, {230, 62, 8, 1.7}, {330, 148, 12, 2.9},
                         {450, 122, 7, 0.9}, {565, 42, 10, 2.2}}) do
        local cx, cy, r, seed = rk[1], rk[2], rk[3], rk[4]
        circle(data, cx, cy, mfloor(r * 1.25), function(dist, a)
            local edge = r * (1 + 0.2 * math.sin(a * 3 + seed) + 0.1 * math.sin(a * 7 + seed * 2))
            if dist > edge then return nil end
            if dist > edge - 1 then return 'K' end
            if math.cos(a) < -0.3 and math.sin(a) < 0 and dist > edge - 3 then return 'd' end
            return 'D'
        end)
    end
    -- observatory dome on the big asteroid, telescope poking out
    circle(data, 70, 133, 9, function(dist, a)
        if math.sin(a) > 0.05 then return nil end            -- top half only
        if dist > 8 then return 'K' end
        if math.abs(math.cos(a)) < 0.12 then return 'K' end  -- the slit
        return 'g'
    end)
    for i = 0, 9 do setPal(data, 72 + i, 127 - mfloor(i * 0.6), 'O') end
    setPal(data, 81, 121, 'Y')
    return toImage(data)
end

---------------------------------------------------------------------------
-- CRYSTAL (level 14): a huge dark cavern full of crystals
---------------------------------------------------------------------------

-- a pointed crystal: dir 1 grows up from baseY, -1 hangs down from it.
-- Lit from the left: light edge, body, dark edge, outlined.
local function crystalShard(data, x, baseY, w, h, dir, light, body, dark, edge)
    local dh = data:getHeight()
    for i = 0, h - 1 do
        local y = baseY - dir * i
        local t = i / mmax(1, h - 1)
        local half = (t < 0.6) and (w / 2) or (w / 2) * (1 - t) / 0.4
        if half < 0.5 then half = 0.5 end
        local x0, x1 = mfloor(x - half + 0.5), mfloor(x + half - 0.5)
        if x1 < x0 then x1 = x0 end
        if y >= 0 and y < dh then
            for px = x0, x1 do
                local letter
                if px == x0 or px == x1 or i == h - 1 then
                    letter = edge
                else
                    local u = (px - x0) / (x1 - x0)
                    letter = (u < 0.35) and light or ((u > 0.7) and dark or body)
                end
                setPal(data, px % LAYER_W, y, letter)
            end
        end
    end
end

local CRYSTAL_FAR_TOP = {{16, 5, 0.5, 3}, {24, 3, 1.9, 6}}
local CRYSTAL_FAR_BOTTOM = {{10, 4, 0.2, 2}, {18, 7, 1.1, 5}}
local CRYSTAL_NEAR_TOP = {{22, 6, 2.0, 8}, {12, 11, 0.4, 4}}
local CRYSTAL_NEAR_BOTTOM = {{12, 3, 0.3, 2}, {8, 11, 1.1, 4}}

-- far layer: cave walls in silhouette and giant dim crystals
local function buildCrystalFar()
    local h = BASE_HEIGHT
    local data = love.image.newImageData(LAYER_W, h)
    for x = 0, LAYER_W - 1 do
        local hang = spikes(x, 4, CRYSTAL_FAR_TOP)
        for y = 0, math.min(h - 1, hang) do setPal(data, x, y, (y == hang) and 'p' or 'K') end
        local rise = h - spikes(x, 10, CRYSTAL_FAR_BOTTOM)
        for y = mmax(0, rise), h - 1 do setPal(data, x, y, (y == rise) and 'p' or 'K') end
    end
    local rng = love.math.newRandomGenerator(1414)
    for i = 0, 7 do
        local x = 40 + i * 80 + rng:random(-15, 15)
        local purple = (i % 2 == 0)
        local light, body = purple and 'v' or 'd', purple and 'p' or 'D'
        crystalShard(data, x, h - 1, rng:random(12, 20), rng:random(70, 120), 1, light, body, 'K', 'K')
        crystalShard(data, x + 40, 0, rng:random(8, 14), rng:random(30, 55), -1, light, body, 'K', 'K')
    end
    return toImage(data, true)
end

-- near layer: dark rocks with bright clusters of purple, orange and silver crystals
local function buildCrystalNear()
    local h = BASE_HEIGHT
    local data = love.image.newImageData(LAYER_W, h)
    for x = 0, LAYER_W - 1 do
        local hang = spikes(x, 0, CRYSTAL_NEAR_TOP)
        for y = 0, math.min(h - 1, hang) do setPal(data, x, y, (y == hang) and 'D' or 'K') end
        local rise = h - spikes(x, 6, CRYSTAL_NEAR_BOTTOM)
        for y = mmax(0, rise), h - 1 do setPal(data, x, y, (y == rise) and 'D' or 'K') end
    end
    local COLORS = { {'W', 'v', 'p'}, {'Y', 'O', 'r'}, {'W', 'g', 'd'} }
    local rng = love.math.newRandomGenerator(77)
    for i = 0, 9 do
        local x = 30 + i * 64 + rng:random(-10, 10)
        local c = COLORS[i % 3 + 1]
        local base = h - spikes(x % LAYER_W, 6, CRYSTAL_NEAR_BOTTOM) + 3
        crystalShard(data, x - 6, base, 5, rng:random(8, 13), 1, c[1], c[2], c[3], 'K')
        crystalShard(data, x + 6, base, 5, rng:random(9, 15), 1, c[1], c[2], c[3], 'K')
        crystalShard(data, x, base, 7, rng:random(14, 24), 1, c[1], c[2], c[3], 'K')
        local hx = x + 32
        local top = spikes(hx % LAYER_W, 0, CRYSTAL_NEAR_TOP) - 3
        crystalShard(data, hx, mmax(0, top), 5, rng:random(8, 14), -1, c[1], c[2], c[3], 'K')
    end
    return toImage(data, true)
end

---------------------------------------------------------------------------
-- JUNGLE (level 15): sunny sky, tall green cliffs with waterfalls, mist,
-- and a thick canopy of jungle trees and palms in front
---------------------------------------------------------------------------

-- the waterfalls painted on the far cliffs: { x, w, top, bottom } (layer
-- pixels). Background.render animates falling streaks on top of them.
local JUNGLE_FALLS = {}

-- far layer: flat-topped cliffs (lit left edge, dark right edge, vertical
-- streaks), waterfalls pouring off them into white mist, low jungle hills
local function buildJungleFar()
    local h = BASE_HEIGHT
    local data = love.image.newImageData(LAYER_W, h)
    local rng = love.math.newRandomGenerator(1515)
    -- {left x, right x, top y}
    local cliffs = { {10, 120, 52}, {150, 230, 78}, {265, 380, 40}, {420, 500, 66}, {530, 625, 48} }
    for _, cl in ipairs(cliffs) do
        local x0, x1, top = cl[1], cl[2], cl[3]
        for x = x0, x1 do
            -- edges lean in a little toward the top
            local inset = mmax(0, 6 - mfloor((x - x0) * 0.6), 6 - mfloor((x1 - x) * 0.6))
            local t = top + inset + ((x * 7) % 3 == 0 and 1 or 0)
            for y = t, h - 1 do
                local letter = 'T'
                if y <= t + 1 then
                    letter = (y == t) and 'L' or 'G'               -- grassy top
                elseif x - x0 < 4 then
                    letter = 'G'                                    -- lit left side
                elseif x1 - x < 5 or (x % 11 == 3 and y > t + 6) then
                    letter = 'j'                                    -- dark side, cracks
                elseif y > t + 2 and y < t + 7 and ((x + y) % 3 == 0) then
                    letter = 'G'                                    -- hanging greenery
                end
                setPal(data, x % LAYER_W, y, letter)
            end
        end
        -- one or two waterfalls off each cliff
        local n = (x1 - x0 > 100) and 2 or 1
        for i = 1, n do
            local fx = x0 + mfloor((x1 - x0) * i / (n + 1)) + rng:random(-8, 8)
            local fw = rng:random(5, 9)
            local ftop = top + 1
            for x = fx, fx + fw - 1 do
                for y = ftop, 150 do
                    local edge = (x == fx or x == fx + fw - 1)
                    setPal(data, x % LAYER_W, y, edge and 'S' or 'C')
                end
            end
            JUNGLE_FALLS[#JUNGLE_FALLS + 1] = { x = fx, w = fw, top = ftop, bottom = 150 }
        end
    end
    -- low jungle hills along the bottom
    for x = 0, LAYER_W - 1 do
        local top = ridge(x, 146, { {5, 4, 0.3}, {3, 11, 1.7}, {2, 23, 0.9} })
        for y = mmax(0, top), h - 1 do
            setPal(data, x, y, (y == top) and 'G' or ((y < top + 3) and 'T' or 'j'))
        end
    end
    -- mist where the falls land: dithered white
    for _, f in ipairs(JUNGLE_FALLS) do
        for y = 136, 156 do
            for x = f.x - 14, f.x + f.w + 14 do
                local d = mabs(x - (f.x + f.w / 2)) / (f.w / 2 + 14) + mabs(y - 146) / 12
                if d < 1 and (1 - d) > bayer(x, y) then setPal(data, x % LAYER_W, y, 'W') end
            end
        end
    end
    return toImage(data)
end

-- near layer: the jungle canopy: round tree crowns, palm trees, big leaves
local function buildJungleNear()
    local h = BASE_HEIGHT
    local data = love.image.newImageData(LAYER_W, h)
    local rng = love.math.newRandomGenerator(1516)
    -- palm trees behind the crowns, poking out above them
    for _, px in ipairs({ 70, 230, 400, 560 }) do
        local base, top = 140, rng:random(62, 78)
        for y = top, base do
            local x = px + mfloor((base - y) * 0.18)
            setPal(data, x % LAYER_W, y, 'b')
            setPal(data, (x + 1) % LAYER_W, y, (y % 6 < 2) and 'b' or 'n')
            setPal(data, (x + 2) % LAYER_W, y, 'b')
        end
        local tx = px + 1 + mfloor((base - top) * 0.18)
        -- drooping fronds, 2 px thick: dark underside, light top
        for _, dir in ipairs({ -1, 1 }) do
            for k = 1, 3 do
                local len = 15 + k * 5
                local droop = 1.2 - k * 0.3
                for i = 0, len do
                    local x = tx + dir * i
                    local y = top - 6 + k * 3 + mfloor(i * i * droop / len)
                    setPal(data, x % LAYER_W, y, (i % 5 == 0) and 'L' or 'G')
                    setPal(data, x % LAYER_W, y + 1, 'j')
                    if i % 3 == 1 and i > 3 then setPal(data, x % LAYER_W, y + 2, 'j') end
                end
            end
        end
        circle(data, tx, top - 2, 3, function(dist) return (dist < 1.5) and 'n' or 'b' end)
    end
    -- crowns: bumpy round trees, lit from the top-left (dithered), dark below
    for i = 0, 19 do
        local cx = i * 32 + rng:random(-5, 5)
        local cy = rng:random(124, 142)
        local r = rng:random(15, 21)
        local seed = rng:random(0, 100)
        fillRect(data, cx - 2, cy, 4, BASE_HEIGHT - cy, 'b')        -- trunk
        fillRect(data, cx - 2, cy, 1, BASE_HEIGHT - cy, 'n')
        circle(data, cx, cy, r + 2, function(dist, a)
            local edge = r + math.sin(a * 7 + seed) * 1.6
            if dist > edge then return nil end
            local lx, ly = math.cos(a) * dist / r, math.sin(a) * dist / r
            local light = (-lx * 0.6 - ly) * 0.7 + 0.15
            local px, py = mfloor(cx + math.cos(a) * dist), mfloor(cy + math.sin(a) * dist)
            if dist > edge - 1.2 and light > 0.2 then return 'L' end
            if light > bayer(px, py) then return 'G' end
            if light < -0.55 then return 'T' end
            return 'j'
        end)
    end
    -- ferns and bushes along the very bottom
    for x = 0, LAYER_W - 1 do
        local top = ridge(x, 166, { {4, 16, 0.2}, {2, 37, 1.1} })
        for y = mmax(0, top), h - 1 do
            setPal(data, x, y, (y == top and x % 3 ~= 0) and 'G' or 'j')
        end
    end
    return toImage(data)
end

function Background.init()
    Background.themes = {
        sky = {
            top = 'S',      -- colour above the pictures on tall screens
            sky = buildGradient('S', 'C', 70, 92),
            clouds = buildClouds(),
            far = buildHills(112, {{10, 2, 0.0}, {6, 5, 1.3}, {3, 11, 2.1}}, 'g', 'W'),
            near = buildHills(138, {{8, 3, 0.7}, {5, 7, 2.4}, {2, 13, 0.3}}, 'G', 'L', 'T', 152),
            wrapY = false,
        },
        cave = {
            top = 'K',
            sky = buildGradient('K', 'D', 110, 175),
            clouds = nil,
            far = buildCaveLayer(
                {{14, 5, 0.5, 3}, {22, 11, 1.7, 6}}, 6,
                {{8, 4, 0.2, 2}, {14, 9, 0.9, 5}}, 14, 'D', 'd'),
            near = buildCaveLayer(
                {{20, 6, 2.0, 8}, {10, 13, 0.4, 4}}, 0,
                {{10, 3, 0.3, 2}, {6, 13, 1.1, 4}}, 8, 'b', 'n'),
            wrapY = true,
        },
        factory = {
            top = 'K',
            sky = buildGradient('K', 'D', 70, 175),
            clouds = nil,
            near = buildFactoryNear(),
            wrapY = true,
        },
    }
    Background.themes.ruins = {
        top = 'T',
        sky = buildGradient('T', 'D', 60, 170),
        clouds = nil,
        far = buildRuinsFar(),
        bubbles = buildBubbles(),
        near = buildRuinsNear(),
        wrapY = true,
    }
    Background.themes.grove = {
        top = 'D',
        sky = buildGradient3('D', 'r', 'O', 40, 80, 120, 170),
        clouds = nil,
        far = buildGroveFar(),
        near = buildGroveNear(),
        fireflies = true,
        wrapY = true,
    }
    Background.themes.ice = {
        top = 'K',
        sky = buildGradient3('K', 'D', 'T', 20, 90, 125, 175),
        clouds = buildAurora(),           -- drifts like the clouds do
        far = buildMountains(),
        near = buildPines(),
        stars = true,
        snow = true,
        wrapY = false,
    }
    Background.themes.space = {
        top = 'K',
        sky = buildGradient('K', 'D', 120, 178),
        clouds = nil,
        far = buildSpaceFar(),
        near = buildSpaceNear(),
        stars = true,
        wrapY = false,
    }
    Background.themes.crystal = {
        top = 'K',
        sky = buildGradient('K', 'p', 90, 178),
        clouds = nil,
        far = buildCrystalFar(),
        near = buildCrystalNear(),
        sparkles = true,
        wrapY = true,
    }
    Background.themes.jungle = {
        top = 'S',
        sky = buildGradient('S', 'C', 70, 125),
        clouds = buildClouds(),
        far = buildJungleFar(),
        near = buildJungleNear(),
        falls = JUNGLE_FALLS,
        birds = true,
        upScale = 0.3,          -- a tall level: the scenery moves up and down less
        wrapY = false,
    }
    -- giant fans turn slowly: 4 pictures, 30 degrees apart (3 blades repeat every 120)
    local frames = {}
    for i = 0, 3 do frames[i + 1] = buildFactoryFar(i * math.pi / 6) end
    Background.themes.factory.farFrames = frames
    Background.themes.factory.far = frames[1]
end

local lg_draw = love.graphics.draw

-- draws a layer repeated sideways across the whole view (any width).
-- wrapY layers also repeat up and down; others are drawn once at offsetY.
local function drawLayer(img, offsetX, offsetY, wrapY)
    local iw, ih = img:getWidth(), img:getHeight()
    local x0 = mfloor(-offsetX % iw) - iw
    local vw, vh = VIRTUAL_WIDTH, VIRTUAL_HEIGHT
    local y0, y1, step
    if wrapY then
        y0 = mfloor(offsetY % ih) - ih
        y1, step = vh, ih
    else
        y0 = mfloor(offsetY)
        if y0 >= vh or y0 + ih <= 0 then return end
        y1, step = y0, ih
    end
    for y = y0, y1, step do
        if y < vh then
            for x = x0, vw, iw do
                lg_draw(img, x, y)
            end
        end
    end
end

-- The pictures are 180 tall. On taller screens they sit at the bottom
-- (baseY) and the top colour of the sky fills the space above.
function Background.render(cameraX, time, cameraY, levelHeight, theme)
    local t = Background.themes[theme or 'sky'] or Background.themes.sky
    local baseY = VIRTUAL_HEIGHT - BASE_HEIGHT

    -- how far the camera is above the bottom of the level (0 = at the bottom)
    local up = 0
    if cameraY and levelHeight then
        up = mmax(0, levelHeight - VIRTUAL_HEIGHT) - cameraY
    end
    if t.upScale then up = up * t.upScale end

    Palette.set(t.top)
    love.graphics.rectangle('fill', 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    love.graphics.setColor(1, 1, 1, 1)
    drawLayer(t.sky, 0, baseY, false)

    -- stars: fixed dots that twinkle (behind everything else)
    if t.stars then
        local vw, vh = VIRTUAL_WIDTH, VIRTUAL_HEIGHT
        for i = 1, 45 do
            local a = 0.45 + 0.55 * math.sin(time * 1.6 + i * 1.3)
            if a > 0.1 then
                local x = (i * 137 - cameraX * 0.02) % vw
                local y = (i * 71 + up * 0.02) % (vh * 0.7)
                Palette.set((i % 7 == 0) and 'Y' or 'W', a)
                love.graphics.rectangle('fill', mfloor(x), mfloor(y), 1, 1)
            end
        end
        love.graphics.setColor(1, 1, 1, 1)
    end

    if t.clouds then
        drawLayer(t.clouds, cameraX * 0.1 + time * 4, baseY + up * 0.05, false)
    end
    local far = t.far
    if t.farFrames then far = t.farFrames[mfloor(time * 5) % #t.farFrames + 1] end
    drawLayer(far, cameraX * 0.25, baseY + up * 0.15, t.wrapY)

    -- jungle: water streaks running down the far waterfalls
    if t.falls then
        local iw = LAYER_W
        local x0 = mfloor(-(cameraX * 0.25) % iw) - iw
        local y0 = mfloor(baseY + up * 0.15)
        local vw = VIRTUAL_WIDTH
        Palette.set('W', 0.8)
        for i = 1, #t.falls do
            local f = t.falls[i]
            local len = f.bottom - f.top
            for k = 0, 2 do
                local sx = x0 + f.x + k * iw
                if sx + f.w >= 0 and sx <= vw then
                    for px = 1, f.w - 2 do
                        local phase = (px * 13) % 17
                        for s = 0, len, 18 do
                            local yy = (s + phase + time * 70) % len
                            love.graphics.rectangle('fill', sx + px, y0 + f.top + mfloor(yy), 1, 4)
                        end
                    end
                end
            end
        end
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- jungle: little birds flapping across the sky
    if t.birds then
        local vw = VIRTUAL_WIDTH
        Palette.set('K', 0.7)
        for i = 1, 5 do
            local speed = 9 + i * 3
            local x = mfloor((i * 151 + time * speed - cameraX * 0.12) % (vw + 40)) - 20
            local y = mfloor(baseY + 20 + (i * 23) % 50 + math.sin(time * 0.8 + i) * 4 + up * 0.08)
            local flap = (mfloor(time * 6 + i) % 2 == 0)
            love.graphics.rectangle('fill', x, y, 1, 1)
            if flap then
                love.graphics.rectangle('fill', x - 2, y - 1, 2, 1)
                love.graphics.rectangle('fill', x + 1, y - 1, 2, 1)
            else
                love.graphics.rectangle('fill', x - 2, y + 1, 2, 1)
                love.graphics.rectangle('fill', x + 1, y + 1, 2, 1)
            end
        end
        love.graphics.setColor(1, 1, 1, 1)
    end

    if t.bubbles then
        drawLayer(t.bubbles, cameraX * 0.35, baseY + up * 0.2 - time * 12, true)
    end
    drawLayer(t.near, cameraX * 0.5, baseY + up * 0.3, t.wrapY)

    -- falling snow: dots drifting down and swaying
    if t.snow then
        local vw, vh = VIRTUAL_WIDTH, VIRTUAL_HEIGHT
        Palette.set('W', 0.75)
        for i = 1, 60 do
            local fall = 14 + (i % 5) * 5
            local x = (i * 61 - cameraX * 0.6 + math.sin(time * 1.1 + i) * 6) % vw
            local y = (i * 37 + time * fall + up * 0.6) % vh
            local s = (i % 6 == 0) and 2 or 1
            love.graphics.rectangle('fill', mfloor(x), mfloor(y), s, s)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- crystal sparkles: dots that flash, the brightest become little stars
    if t.sparkles then
        local vw, vh = VIRTUAL_WIDTH, VIRTUAL_HEIGHT
        local SPARK = {'W', 'v', 'O', 'C'}
        for i = 1, 24 do
            local a = math.sin(time * 1.3 + i * 2.7)
            if a > 0.4 then
                local x = mfloor((i * 89 - cameraX * 0.5) % vw)
                local y = mfloor((i * 47 + up * 0.3) % vh)
                Palette.set(SPARK[i % 4 + 1], (a - 0.4) / 0.6)
                love.graphics.rectangle('fill', x, y, 1, 1)
                if a > 0.85 then
                    love.graphics.rectangle('fill', x - 1, y, 1, 1)
                    love.graphics.rectangle('fill', x + 1, y, 1, 1)
                    love.graphics.rectangle('fill', x, y - 1, 1, 1)
                    love.graphics.rectangle('fill', x, y + 1, 1, 1)
                end
            end
        end
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- fireflies: tiny dots that drift and blink (no images needed)
    if t.fireflies then
        local vw, vh = VIRTUAL_WIDTH, VIRTUAL_HEIGHT
        for i = 1, 28 do
            local a = math.sin(time * 2.3 + i * 2.1)
            if a > 0 then
                local x = (i * 97 - cameraX * 0.4 + math.sin(time * 0.7 + i) * 10) % vw
                local y = (i * 53 + up * 0.35 + math.cos(time * 0.9 + i * 1.7) * 6) % vh
                Palette.set((i % 3 == 0) and 'Y' or 'L', 0.35 + 0.65 * a)
                love.graphics.rectangle('fill', mfloor(x), mfloor(y), 1, 1)
            end
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
end
