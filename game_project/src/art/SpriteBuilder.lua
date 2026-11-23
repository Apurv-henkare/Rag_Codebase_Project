--[[
    Inflate - SpriteBuilder
    Turns text-grid sprites into LÖVE images and quads at load time.

    A grid is a list of equal-length strings; each character is a Palette letter
    ('.' = transparent). A sprite is a list of frames (grids). All frames of one
    sprite are packed side by side into one texture, 1px apart.

    Result:
        gTextures[name] = Image
        gFrames[name]   = { Quad, Quad, ... }   (use quad:getViewport() for frame size)
]]

SpriteBuilder = {}

local GAP = 1   -- empty pixels between frames, prevents bleeding

-- checks a grid and returns its width/height (errors name the sprite and row)
local function measure(name, f, grid)
    local h = #grid
    assert(h > 0, ('Sprite "%s" frame %d is empty'):format(name, f))
    local w = #grid[1]
    for y = 1, h do
        local row = grid[y]
        assert(#row == w, ('Sprite "%s" frame %d row %d is %d wide, expected %d')
            :format(name, f, y, #row, w))
        for x = 1, w do
            local ch = row:sub(x, x)
            assert(ch == '.' or Palette.colors[ch],
                ('Sprite "%s" frame %d row %d has unknown letter "%s"'):format(name, f, y, ch))
        end
    end
    return w, h
end

-- writes one grid into imageData at (ox, oy)
local function paint(imageData, grid, ox, oy)
    local colors = Palette.colors
    for y = 1, #grid do
        local row = grid[y]
        for x = 1, #row do
            local ch = row:sub(x, x)
            if ch ~= '.' then
                local c = colors[ch]
                imageData:setPixel(ox + x - 1, oy + y - 1, c[1], c[2], c[3], 1)
            end
        end
    end
end

-- frames: list of grids. Returns Image, {quads}
function SpriteBuilder.build(name, frames)
    local sizes = {}
    local totalW, maxH = 0, 0
    for f = 1, #frames do
        local w, h = measure(name, f, frames[f])
        sizes[f] = {w, h}
        totalW = totalW + w + (f > 1 and GAP or 0)
        if h > maxH then maxH = h end
    end

    local data = love.image.newImageData(totalW, maxH)
    local x = 0
    local quadsPos = {}
    for f = 1, #frames do
        paint(data, frames[f], x, 0)
        quadsPos[f] = x
        x = x + sizes[f][1] + GAP
    end

    local image = love.graphics.newImage(data)
    image:setFilter('nearest', 'nearest')

    local quads = {}
    for f = 1, #frames do
        quads[f] = love.graphics.newQuad(quadsPos[f], 0, sizes[f][1], sizes[f][2], totalW, maxH)
    end
    return image, quads
end

-- builds every sprite in a {name = {frames...}} table into gTextures / gFrames
function SpriteBuilder.buildAll(defs, textures, frames)
    for name, frameList in pairs(defs) do
        textures[name], frames[name] = SpriteBuilder.build(name, frameList)
    end
end

-- draws frame `i` of sprite `name` with its top-left at (x, y), snapped to whole pixels.
-- flipX mirrors horizontally around the frame's own width.
local lg_draw, mfloor = love.graphics.draw, math.floor
function SpriteBuilder.draw(name, i, x, y, flipX)
    local quad = gFrames[name][i]
    if flipX then
        local _, _, w = quad:getViewport()
        lg_draw(gTextures[name], quad, mfloor(x) + w, mfloor(y), 0, -1, 1)
    else
        lg_draw(gTextures[name], quad, mfloor(x), mfloor(y))
    end
end
