--[[
    Inflate - PixelFont
    A 7px-tall pixel font drawn as grids, turned into a LÖVE ImageFont.
    Lowercase letters reuse the uppercase shapes (classic all-caps retro look).

    Use PixelFont.print() for text: it snaps to whole pixels and supports
    integer scale, alignment, palette colours, drop shadow and outline.
]]

PixelFont = {}

local G = {}   -- char -> rows ('#' = pixel). Width = row length.

G['A'] = {".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"}
G['B'] = {"####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."}
G['C'] = {".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."}
G['D'] = {"####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."}
G['E'] = {"#####", "#....", "#....", "####.", "#....", "#....", "#####"}
G['F'] = {"#####", "#....", "#....", "####.", "#....", "#....", "#...."}
G['G'] = {".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"}
G['H'] = {"#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"}
G['I'] = {"###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"}
G['J'] = {"..###", "...#.", "...#.", "...#.", "#..#.", "#..#.", ".##.."}
G['K'] = {"#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"}
G['L'] = {"#....", "#....", "#....", "#....", "#....", "#....", "#####"}
G['M'] = {"#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"}
G['N'] = {"#...#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"}
G['O'] = {".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."}
G['P'] = {"####.", "#...#", "#...#", "####.", "#....", "#....", "#...."}
G['Q'] = {".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"}
G['R'] = {"####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"}
G['S'] = {".####", "#....", "#....", ".###.", "....#", "....#", "####."}
G['T'] = {"#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."}
G['U'] = {"#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."}
G['V'] = {"#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."}
G['W'] = {"#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"}
G['X'] = {"#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"}
G['Y'] = {"#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."}
G['Z'] = {"#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"}

G['0'] = {".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."}
G['1'] = {".#.", "##.", ".#.", ".#.", ".#.", ".#.", "###"}
G['2'] = {".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"}
G['3'] = {"####.", "....#", "....#", ".###.", "....#", "....#", "####."}
G['4'] = {"...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."}
G['5'] = {"#####", "#....", "####.", "....#", "....#", "#...#", ".###."}
G['6'] = {".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."}
G['7'] = {"#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."}
G['8'] = {".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."}
G['9'] = {".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."}

G[' '] = {"...", "...", "...", "...", "...", "...", "..."}
G['.'] = {".", ".", ".", ".", ".", ".", "#"}
G[','] = {"..", "..", "..", "..", "..", ".#", "#."}
G['!'] = {"#", "#", "#", "#", "#", ".", "#"}
G['?'] = {".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."}
G[':'] = {".", ".", "#", ".", ".", "#", "."}
G['-'] = {"...", "...", "...", "###", "...", "...", "..."}
G['+'] = {".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."}
G['/'] = {"..#", "..#", ".#.", ".#.", ".#.", "#..", "#.."}
G["'"] = {"#", "#", ".", ".", ".", ".", "."}
G['('] = {".#", "#.", "#.", "#.", "#.", "#.", ".#"}
G[')'] = {"#.", ".#", ".#", ".#", ".#", ".#", "#."}
G['<'] = {"...#", "..#.", ".#..", "#...", ".#..", "..#.", "...#"}
G['>'] = {"#...", ".#..", "..#.", "...#", "..#.", ".#..", "#..."}
G['='] = {"....", "....", "####", "....", "####", "....", "...."}
G['%'] = {"##..#", "##.#.", "...#.", "..#..", ".#...", ".#.##", "#..##"}
G['#'] = {".#.#.", "#####", ".#.#.", ".#.#.", ".#.#.", "#####", ".#.#."}

local GLYPH_H = 7

local function build()
    -- order of glyphs; lowercase reuses uppercase rows
    local order = {}
    for c in pairs(G) do order[#order + 1] = c end
    table.sort(order)
    local chars, rowsList = {}, {}
    for i = 1, #order do
        local c = order[i]
        chars[#chars + 1] = c
        rowsList[#rowsList + 1] = G[c]
        if c:match('%u') then
            chars[#chars + 1] = c:lower()
            rowsList[#rowsList + 1] = G[c]
        end
    end

    -- image: separator column, glyph, separator, glyph, ... separator
    local width = 1
    for i = 1, #rowsList do
        local rows = rowsList[i]
        assert(#rows == GLYPH_H, 'Glyph "' .. chars[i] .. '" must have 7 rows')
        for r = 2, GLYPH_H do
            assert(#rows[r] == #rows[1], 'Glyph "' .. chars[i] .. '" rows differ in width')
        end
        width = width + #rows[1] + 1
    end

    local data = love.image.newImageData(width, GLYPH_H)
    local x = 0
    local function separator()
        for y = 0, GLYPH_H - 1 do data:setPixel(x, y, 1, 0, 1, 1) end
        x = x + 1
    end
    separator()
    for i = 1, #rowsList do
        local rows = rowsList[i]
        local w = #rows[1]
        for y = 1, GLYPH_H do
            for gx = 1, w do
                if rows[y]:sub(gx, gx) == '#' then
                    data:setPixel(x + gx - 1, y - 1, 1, 1, 1, 1)
                end
            end
        end
        x = x + w
        separator()
    end

    local font = love.graphics.newImageFont(data, table.concat(chars), 1)
    font:setFilter('nearest', 'nearest')
    font:setLineHeight(10 / GLYPH_H)
    return font
end

PixelFont.font = build()
PixelFont.HEIGHT = GLYPH_H

--[[
    PixelFont.makeLogo(text, block, colors) -> Image
    Builds a title logo as real pixel art at native resolution (no scaled-up
    pixels): each font pixel becomes a block x block square, then the shape gets
    a 1px highlight, a bottom shade, a 1px outline and a 2px drop shadow.
    colors = {top, fill, shade, outline, shadow} palette letters.
]]
function PixelFont.makeLogo(text, block, colors)
    text = text:upper()
    local top, fill, shade, outline, shadow =
        colors[1], colors[2], colors[3], colors[4], colors[5]
    local PAD = 3   -- room for outline (1) + shadow (2)

    -- glyph columns -> mask
    local width = PAD * 2
    for i = 1, #text do
        local g = assert(G[text:sub(i, i)], 'No glyph for ' .. text:sub(i, i))
        width = width + #g[1] * block + (i > 1 and block or 0)
    end
    local height = GLYPH_H * block + PAD * 2

    local mask = {}
    local function set(x, y) mask[y * width + x] = true end
    local function has(x, y)
        return x >= 0 and y >= 0 and x < width and y < height and mask[y * width + x] == true
    end

    local cx = PAD
    for i = 1, #text do
        local g = G[text:sub(i, i)]
        if i > 1 then cx = cx + block end
        for gy = 1, GLYPH_H do
            for gx = 1, #g[1] do
                if g[gy]:sub(gx, gx) == '#' then
                    for by = 0, block - 1 do
                        for bx = 0, block - 1 do
                            set(cx + (gx - 1) * block + bx, PAD - 1 + (gy - 1) * block + by)
                        end
                    end
                end
            end
        end
        cx = cx + #g[1] * block
    end

    local function isOutline(x, y)
        if has(x, y) then return false end
        for oy = -1, 1 do
            for ox = -1, 1 do
                if has(x + ox, y + oy) then return true end
            end
        end
        return false
    end

    local data = love.image.newImageData(width, height)
    local function put(x, y, letter)
        local c = Palette.get(letter)
        data:setPixel(x, y, c[1], c[2], c[3], 1)
    end
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            if has(x, y) then
                if not has(x, y - 1) then put(x, y, top)
                elseif not has(x, y + 1) or not has(x, y + 2) then put(x, y, shade)
                else put(x, y, fill) end
            elseif isOutline(x, y) then
                put(x, y, outline)
            elseif has(x, y - 1) or isOutline(x, y - 1)
                or has(x, y - 2) or isOutline(x, y - 2) then
                put(x, y, shadow)
            end
        end
    end

    local img = love.graphics.newImage(data)
    img:setFilter('nearest', 'nearest')
    return img
end

-- width of text in virtual pixels at a given scale
function PixelFont.width(text, scale)
    return PixelFont.font:getWidth(text) * (scale or 1)
end

local lg = love.graphics
local mfloor = math.floor

--[[
    PixelFont.print(text, x, y, opts)
      opts.scale   integer scale (default 1)
      opts.align   'left' | 'center' | 'right'  (relative to x .. x+opts.width)
      opts.width   area width for align (default VIRTUAL_WIDTH)
      opts.color   palette letter (default 'W')
      opts.shadow  palette letter for a 1-pixel (x scale) drop shadow
      opts.outline palette letter for a 1-pixel (x scale) outline
      opts.alpha   0..1
]]
function PixelFont.print(text, x, y, opts)
    opts = opts or {}
    local s = opts.scale or 1
    local align = opts.align or 'left'
    if align ~= 'left' then
        local areaW = opts.width or PixelFont.areaWidth or VIRTUAL_WIDTH
        local tw = PixelFont.font:getWidth(text) * s
        if align == 'center' then x = x + (areaW - tw) / 2
        else x = x + areaW - tw end
    end
    x, y = mfloor(x), mfloor(y)
    local a = opts.alpha or 1

    lg.setFont(PixelFont.font)
    -- draw order: shadow (under everything) -> outline -> fill
    local ring = opts.outline and 1 or 0
    if opts.shadow then
        -- shadow is the whole (outlined) shape pushed down one pixel
        Palette.set(opts.shadow, a)
        for oy = -ring, ring do
            for ox = -ring, ring do
                lg.print(text, x + ox * s, y + (oy + 1) * s, 0, s, s)
            end
        end
    end
    if opts.outline then
        Palette.set(opts.outline, a)
        for oy = -1, 1 do
            for ox = -1, 1 do
                if ox ~= 0 or oy ~= 0 then
                    lg.print(text, x + ox * s, y + oy * s, 0, s, s)
                end
            end
        end
    end
    Palette.set(opts.color or 'W', a)
    lg.print(text, x, y, 0, s, s)
    lg.setColor(1, 1, 1, 1)
end
