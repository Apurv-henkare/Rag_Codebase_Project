--[[
    Inflate - JungleSprites
    The art for level 15 "Wild Falls" (theme 'jungle'): tiles, the dark cave
    wall behind cave passages, decorations and the jungle creatures.

    Most creatures are painted with simple shapes (ellipses, boxes) on a
    small pixel canvas and then outlined in black, so every frame keeps the
    same clean look. Same rules as Sprites.lua: Palette letters, '.' = clear.
    Loaded after Sprites.lua; everything goes into Sprites.defs.
]]

local defs = Sprites.defs

---------------------------------------------------------------------------
-- little pixel canvas
---------------------------------------------------------------------------

local function canvas(w, h)
    local c = { w = w, h = h, px = {} }
    for y = 1, h do
        local row = {}
        for x = 1, w do row[x] = '.' end
        c.px[y] = row
    end
    return c
end

local function set(c, x, y, l)
    if x >= 1 and x <= c.w and y >= 1 and y <= c.h then c.px[y][x] = l end
end

local function rect(c, x, y, w, h, l)
    for yy = y, y + h - 1 do
        for xx = x, x + w - 1 do set(c, xx, yy, l) end
    end
end

-- filled ellipse; (cx, cy) in pixel coordinates (pixel centres are whole numbers)
local function ellipse(c, cx, cy, rx, ry, l)
    for y = 1, c.h do
        for x = 1, c.w do
            local dx, dy = (x - cx) / rx, (y - cy) / ry
            if dx * dx + dy * dy <= 1 then set(c, x, y, l) end
        end
    end
end

-- black outline around everything painted (clear pixels touching colour)
local function outline(c)
    local add = {}
    local px = c.px
    local function filled(x, y)
        local r = px[y]
        local v = r and r[x]
        return v ~= nil and v ~= '.' and v ~= 'K'
    end
    for y = 1, c.h do
        for x = 1, c.w do
            if px[y][x] == '.' and (filled(x - 1, y) or filled(x + 1, y)
                or filled(x, y - 1) or filled(x, y + 1)) then
                add[#add + 1] = { x, y }
            end
        end
    end
    for i = 1, #add do px[add[i][2]][add[i][1]] = 'K' end
end

local function rows(c)
    local out = {}
    for y = 1, c.h do out[y] = table.concat(c.px[y]) end
    return out
end

local function recolor(grid, map)
    local out = {}
    for i = 1, #grid do
        out[i] = (grid[i]:gsub('.', function(ch) return map[ch] or ch end))
    end
    return out
end

local function flipRows(grid)
    local out = {}
    for i = #grid, 1, -1 do out[#out + 1] = grid[i] end
    return out
end

-- a squashed creature: a flat body with two eyes on top
local function squashed(w, h, body, belly)
    local c = canvas(w, h)
    ellipse(c, w / 2 + 0.5, h - 1, w / 2 - 1, 1.6, body)
    rect(c, 4, h - 1, w - 7, 1, belly)
    set(c, 6, h - 3, 'W'); set(c, w - 5, h - 3, 'W')
    outline(c)
    return rows(c)
end

---------------------------------------------------------------------------
-- TILES (16 x 16)
---------------------------------------------------------------------------

-- dark jungle soil with roots
local SOIL = {
    "bbbbbbbbbbbbbbbb",
    "bbnbbbbbbbbbbbbb",
    "bbbbbbbKbbbbbnbb",
    "bbbbbbKbbbbbbbbb",
    "bnbbbbbbbbbbbbbb",
    "bbbbbbbbbbjbbbbb",
    "bbbbbnbbbbbbbbbb",
    "bbbbbbbbbbbbbbKb",
    "bKbbbbbbbbbbbKbb",
    "bbKbbbbbnbbbbbbb",
    "bbbbbbbbbbbbbbbb",
    "bbbbbbbbbbbbnbbb",
    "bbbnbbbbKbbbbbbb",
    "bbbbbbbKbbbbbbbb",
    "bbbbbbbbbbbbbbbb",
    "bbbbbjbbbbbbbbnb",
}
defs['jungle-soil'] = { SOIL }

-- soil with thick jungle grass on top
defs['jungle-top'] = {{
    "LLGLLLLGLLLGLLLL",
    "GLGGLGGGGLGGGLGG",
    "GGGGGGjGGGGGGjGG",
    "jGjGGjjGjGGjGjjG",
    "jjbjjbjjjbjjjbjj",
    "bjbbbbjbbbbbjbbb",
    SOIL[7], SOIL[8], SOIL[9], SOIL[10], SOIL[11],
    SOIL[12], SOIL[13], SOIL[14], SOIL[15], SOIL[16],
}}

-- soil underside (cave ceilings): moss and little roots
defs['jungle-bottom'] = {{
    SOIL[1], SOIL[2], SOIL[3], SOIL[4], SOIL[5], SOIL[6],
    SOIL[7], SOIL[8], SOIL[9], SOIL[10], SOIL[11],
    "bbjbbbbbbjbbbbbb",
    "jbjjbbjbjjjbbjbj",
    "jGjjGjjjGjjGjjGj",
    "GjGjjGGjjGjGjjGj",
    "jjGjjjjGjjjjGjjG",
}}

-- old temple stone (=), overgrown with moss
local STONE = defs['stone'][1]
defs['mossy-stone'] = {{
    "GLGGLGGLLGGLGGLG",
    "GGjGGdGGjGGdGjGK",
    STONE[3], STONE[4], STONE[5], STONE[6], STONE[7], STONE[8],
    "GggKgggggGGKgggg",
    STONE[10], STONE[11], STONE[12], STONE[13], STONE[14], STONE[15], STONE[16],
}}

-- cracked temple stone (C): the Big ball breaks it
defs['jungle-cracked'] = { recolor(defs['cracked'][1], { g = 'G' }) }

-- thorns (^ on floors, v under ceilings): orange spikes, hurt like spikes
defs['thorns'] = { recolor(defs['spikes'][1], { W = 'Y', g = 'O', d = 'r', D = 'j' }) }
defs['thorns-down'] = { flipRows(defs['thorns'][1]) }

-- the dark wall seen behind cave passages (not solid, drawn behind everything)
defs['jungle-cave'] = {
    {
        "KKKKDKKKKKKKKKKK",
        "KKKKKKKKKKDKKKKK",
        "KDKKKKKKKKKKKKKK",
        "KKKKKKKjKKKKKKDK",
        "KKKKKKjKKKKKKKKK",
        "KKKDKKKKKKKKKKKK",
        "KKKKKKKKKDKKKKKK",
        "KKKKKKKKKKKKKjKK",
        "KjKKKKKKKKKKjKKK",
        "KKKKKKDKKKKKKKKK",
        "KKKKKKKKKKKKKKKK",
        "KKKKKKKKKKKKDKKK",
        "KKDKKKKKKjKKKKKK",
        "KKKKKKKKjKKKKKKK",
        "KKKKKKKKKKKKKKDK",
        "KKKKKjKKKKKKKKKK",
    },
    {
        "KKKKKKbKKKKKKKKK",
        "KKKKKKbKKKDKKKKK",
        "KDKKKKKbKKKKKKKK",
        "KKKKKKKbKKKKKKDK",
        "KKKKKKbKKKKKKKKK",
        "KKKDKKbKKKKKKKKK",
        "KKKKKbKKKDKKKKKK",
        "KKKKKbKKKKKKKjKK",
        "KjKKKKbKKKKKjKKK",
        "KKKKKKjKKKKKKKKK",
        "KKKKKKKKKKKKKKKK",
        "KKKKKKKKKKKKDKKK",
        "KKDKKKKKKjKKKKKK",
        "KKKKKKKKjKKKKKKK",
        "KKKKKKKKKKKKKKDK",
        "KKKKKjKKKKKKKKKK",
    },
}

---------------------------------------------------------------------------
-- DECORATIONS (16 x 16)
---------------------------------------------------------------------------

-- x: glowing cave mushrooms
do
    local c = canvas(16, 16)
    rect(c, 5, 11, 2, 5, 'W'); ellipse(c, 5.5, 10, 3.5, 2, 'C'); set(c, 4, 9, 'W')
    rect(c, 11, 13, 1, 3, 'W'); ellipse(c, 11, 12.5, 2.5, 1.5, 'C'); set(c, 10, 12, 'W')
    rect(c, 14, 14, 1, 2, 'W'); ellipse(c, 14, 13.5, 1.5, 1, 'S')
    outline(c)
    defs['glow-mushroom'] = { rows(c) }
end

-- y: a big jungle flower on its leaves
do
    local c = canvas(16, 16)
    ellipse(c, 4, 13, 3.5, 1.5, 'G'); ellipse(c, 12.5, 13, 3.5, 1.5, 'G')
    rect(c, 8, 9, 1, 7, 'j')
    for _, p in ipairs({ {8, 4}, {5, 6.5}, {11.5, 6.5}, {6, 9.5}, {10.5, 9.5} }) do
        ellipse(c, p[1], p[2], 2.4, 2.1, 'R')
    end
    ellipse(c, 8, 7.5, 2, 2, 'Y'); set(c, 8, 7, 'O'); set(c, 7, 8, 'O')
    set(c, 7, 3, 'O'); set(c, 4, 6, 'O')
    outline(c)
    defs['jungle-flower'] = { rows(c) }
end

-- z: a fern bush
do
    local c = canvas(16, 16)
    -- fronds: thin arcs going out from the base
    local fronds = { {-1, 0.9}, {-0.55, 1.1}, {0, 1.2}, {0.55, 1.1}, {1, 0.9} }
    for _, f in ipairs(fronds) do
        local dirX, len = f[1], f[2]
        for t = 0, 10 do
            local x = 8.5 + dirX * t * 0.75
            local y = 16 - t * len + (dirX * dirX) * t * t * 0.06
            set(c, math.floor(x + 0.5), math.floor(y + 0.5), (t % 3 == 0) and 'L' or 'G')
            if t > 2 and t < 9 then set(c, math.floor(x + 0.5) + 1, math.floor(y + 0.5), 'j') end
        end
    end
    outline(c)
    defs['fern'] = { rows(c) }
end

-- coconut thrown by monkeys (6 x 6)
defs['coconut'] = {{
    ".KKKK.",
    "KbnbbK",
    "KnbbbK",
    "KbbbnK",
    "KbbbbK",
    ".KKKK.",
}}

---------------------------------------------------------------------------
-- CREATURES (all face right; direction -1 mirrors them)
---------------------------------------------------------------------------

-- FROG (16 x 16, bottom on row 16): 1 sitting, 2 crouching (about to hop),
-- 3 jumping, 4 knocked over, 5 squashed
local function frog(pose)
    local c = canvas(16, 16)
    local dy = (pose == 'crouch') and 1 or ((pose == 'jump') and -2 or 0)
    if pose == 'jump' then
        rect(c, 1, 12, 4, 2, 'G'); rect(c, 1, 14, 2, 1, 'L')     -- back legs stretched out
        rect(c, 12, 13, 2, 3, 'G')                               -- front legs down
    else
        ellipse(c, 5, 13.5 + dy * 0.5, 3, 2.3, 'G')              -- folded back leg
        rect(c, 2, 16, 4, 1, 'G')                                -- back foot
        rect(c, 12, 15, 3, 2, 'G')                               -- front foot
    end
    ellipse(c, 8.5, 12 + dy, 6, 3.4, 'G')                        -- body
    ellipse(c, 10, 13.5 + dy, 4, 1.8, 'L')                       -- belly
    set(c, 5, 10 + dy, 'L'); set(c, 7, 9 + dy, 'L')              -- shine
    set(c, 4, 12 + dy, 'j'); set(c, 6, 11 + dy, 'j')             -- spots
    ellipse(c, 10.5, 8.6 + dy, 1.7, 1.7, 'G')                    -- eye bumps
    ellipse(c, 13.5, 8.6 + dy, 1.7, 1.7, 'G')
    set(c, 10, 8 + dy, 'W'); set(c, 11, 8 + dy, 'K')
    set(c, 13, 8 + dy, 'W'); set(c, 14, 8 + dy, 'K')
    rect(c, 12, 12 + dy, 3, 1, 'j')                              -- mouth
    outline(c)
    return rows(c)
end
defs['frog'] = {
    frog('sit'), frog('crouch'), frog('jump'), flipRows(frog('sit')),
    squashed(16, 16, 'G', 'L'),
}

-- SNAKE (16 x 16): 1 hiding in the grass (only its eyes show), 2 raised,
-- 3 striking (mouth open), 4 knocked over, 5 squashed
local SNAKE_HIDE = {
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "..L...KK.KK...L.",
    ".LG..KYKKYK..LG.",
    ".GL.LKKKKKKL.GL.",
    "LGGLGGLGGLGGLGGL",
    "GjGGjGGjGGjGGjGG",
    "jjjjjjjjjjjjjjjj",
}
local function snake(strike)
    local c = canvas(16, 16)
    ellipse(c, 6.5, 14.5, 5.5, 2, 'G')                           -- coils
    ellipse(c, 6, 14, 3.5, 0.9, 'L')
    set(c, 3, 15, 'j'); set(c, 7, 15, 'j'); set(c, 10, 15, 'j')
    if strike then
        rect(c, 9, 10, 3, 5, 'G'); rect(c, 11, 8, 3, 3, 'G')     -- neck reaching forward
        rect(c, 11, 11, 1, 4, 'Y')
        ellipse(c, 13.5, 6.5, 2.6, 2.2, 'G')                     -- head
        rect(c, 13, 7, 4, 2, 'r')                                -- open mouth
        set(c, 14, 7, 'W'); set(c, 16, 7, 'W')                   -- fangs
        set(c, 13, 5, 'Y'); set(c, 14, 5, 'K')                   -- eye
    else
        rect(c, 9, 8, 3, 7, 'G')                                 -- neck
        rect(c, 11, 9, 1, 6, 'Y')                                -- belly stripe
        ellipse(c, 11.5, 6.5, 3, 2, 'G')                         -- head
        set(c, 12, 6, 'Y'); set(c, 13, 6, 'K')                   -- eye
        rect(c, 12, 7, 3, 1, 'j')                                -- mouth line
        set(c, 15, 8, 'R'); set(c, 16, 7, 'R'); set(c, 16, 9, 'R')  -- tongue
    end
    set(c, 9, 10, 'L'); set(c, 10, 12, 'L')                      -- scales
    outline(c)
    return rows(c)
end
defs['snake'] = {
    SNAKE_HIDE, snake(false), snake(true), flipRows(snake(false)),
    squashed(16, 16, 'G', 'Y'),
}

-- MONKEY (16 x 16): 1-2 sitting (2 blinks), 3 throwing, 4 knocked over, 5 squashed
local function monkey(pose)
    local c = canvas(16, 16)
    -- tail curling up behind it
    for _, p in ipairs({ {2, 14}, {1, 13}, {1, 12}, {1, 11}, {2, 10}, {3, 10} }) do
        set(c, p[1], p[2], 'b')
    end
    ellipse(c, 8, 11.5, 4, 3.5, 'n')                             -- body
    ellipse(c, 8.5, 12, 2.4, 2.4, 'Y')                           -- belly
    rect(c, 5, 14, 3, 2, 'b'); rect(c, 9, 14, 3, 2, 'b')         -- legs
    rect(c, 4, 9, 2, 5, 'n')                                     -- back arm
    if pose == 'throw' then
        rect(c, 12, 3, 2, 7, 'n')                                -- arm up ...
        ellipse(c, 13, 2.2, 1.7, 1.7, 'b')                       -- ... holding a coconut
        set(c, 13, 2, 'n')
    else
        rect(c, 12, 9, 2, 5, 'n')                                -- front arm
    end
    ellipse(c, 4.8, 5, 1.4, 1.4, 'n'); ellipse(c, 12.4, 5, 1.4, 1.4, 'n')   -- ears
    set(c, 5, 5, 'O'); set(c, 12, 5, 'O')
    ellipse(c, 8.5, 5.5, 3.5, 3, 'n')                            -- head
    ellipse(c, 9.2, 6.3, 2.6, 2, 'Y')                            -- face
    local eye = (pose == 'blink') and 'n' or 'K'
    set(c, 8, 5, eye); set(c, 11, 5, eye)
    set(c, 9, 7, 'r'); set(c, 10, 7, 'r')                        -- grin
    outline(c)
    return rows(c)
end
defs['monkey'] = {
    monkey('sit'), monkey('blink'), monkey('throw'), flipRows(monkey('sit')),
    squashed(16, 16, 'n', 'Y'),
}

-- JUNGLE BEETLE (flying, 16 x 16): 1-2 flying (wings up / down), 3 squashed,
-- 4 angry (red eye, about to dive)
local function bug(wingsUp, angry)
    local c = canvas(16, 16)
    if wingsUp then
        ellipse(c, 6, 5, 3, 2, 'W'); ellipse(c, 9.5, 4.5, 2.5, 2, 'C')
    else
        ellipse(c, 3.5, 7.5, 3, 1.5, 'W'); ellipse(c, 5, 6.5, 2.5, 1.3, 'C')
    end
    ellipse(c, 7.5, 10, 5, 3, 'T')                               -- shell
    ellipse(c, 6, 9, 2.5, 1.1, 'C')                              -- shine
    set(c, 7, 12, 'j'); set(c, 4, 11, 'j'); set(c, 10, 12, 'j')
    ellipse(c, 12.5, 10.5, 2, 2, 'j')                            -- head
    set(c, 14, 9, 'g'); set(c, 15, 8, 'g'); set(c, 15, 7, 'W')   -- horn
    set(c, 13, 10, angry and 'R' or 'Y')                         -- eye
    set(c, 5, 13, 'K'); set(c, 8, 13, 'K'); set(c, 11, 13, 'K')  -- legs
    set(c, 5, 14, 'K'); set(c, 8, 14, 'K'); set(c, 11, 14, 'K')
    outline(c)
    return rows(c)
end
defs['flybug'] = {
    bug(true, false), bug(false, false), squashed(16, 16, 'T', 'C'), bug(true, true),
}

-- SNAPPER PLANT (16 x 32, stands on the bottom row): 1 closed, 2 open (about
-- to bite), 3 biting (stretched up high), 4 tired (droops, safe to pass)
local function leaves(c)
    ellipse(c, 4.5, 29.5, 3.5, 1.5, 'G'); ellipse(c, 12.5, 29.5, 3.5, 1.5, 'G')
    set(c, 3, 29, 'L'); set(c, 13, 29, 'L')
    rect(c, 5, 31, 8, 2, 'j')
end
local function plant(pose)
    local c = canvas(16, 32)
    if pose == 'bite' then
        rect(c, 8, 9, 2, 22, 'G'); rect(c, 9, 9, 1, 22, 'j')     -- long stalk
        ellipse(c, 6.5, 18, 2, 1, 'G')                           -- a leaf on it
        leaves(c)
        ellipse(c, 8.5, 6, 4.6, 3.6, 'R')                        -- jaws snapped shut
        set(c, 6, 4, 'Y'); set(c, 10, 4, 'Y'); set(c, 8, 8, 'Y')
        for x = 5, 12 do set(c, x, 6, (x % 2 == 0) and 'W' or 'K') end
    else
        rect(c, 8, 25, 2, 6, 'G'); rect(c, 9, 25, 2, 6, 'j')
        leaves(c)
        if pose == 'open' then
            ellipse(c, 8.5, 18.5, 4.6, 2.3, 'R')                 -- top jaw
            ellipse(c, 8.5, 23.5, 4.6, 2.3, 'R')                 -- bottom jaw
            rect(c, 5, 20, 8, 3, 'r')                            -- inside of the mouth
            for x = 5, 12 do
                if x % 2 == 0 then set(c, x, 20, 'W') else set(c, x, 22, 'W') end
            end
            set(c, 6, 17, 'Y'); set(c, 11, 17, 'Y'); set(c, 9, 25, 'Y')
        else
            ellipse(c, 8.5, 21, 3.6, 3.1, 'R')                   -- closed bud
            set(c, 7, 19, 'Y'); set(c, 10, 20, 'Y'); set(c, 8, 23, 'Y')
            set(c, 6, 21, 'r'); set(c, 11, 22, 'r')
        end
    end
    outline(c)
    return rows(c)
end
defs['snapper'] = {
    plant('closed'), plant('open'), plant('bite'),
    recolor(plant('closed'), { R = 'r', Y = 'O', G = 'j', L = 'G' }),
}

-- PIRANHA (16 x 12): 1-2 swimming (tail flicks), 3 biting (mouth wide open)
local function piranha(flick, bite)
    local c = canvas(16, 12)
    -- tail fin on the left
    -- forked tail fin (flick: spread wider)
    local t = flick and 1 or 0
    rect(c, 3, 5, 2, 3, 'd')
    set(c, 2, 4, 'd'); set(c, 2, 8, 'd')
    set(c, 1, 3 - t, 'D'); set(c, 2, 3 - t, 'd'); set(c, 1, 9 + t, 'D'); set(c, 2, 9 + t, 'd')
    ellipse(c, 9.5, 6.5, 5.6, 4, 'd')                            -- body
    ellipse(c, 9, 5, 4.6, 2.2, 'g')                              -- light back
    ellipse(c, 10, 8.6, 4.5, 1.8, 'R')                           -- red belly
    set(c, 8, 2, 'd'); set(c, 9, 2, 'd'); set(c, 10, 1, 'd')     -- top fin
    set(c, 12, 5, 'W'); set(c, 13, 5, 'K')                       -- eye
    if bite then
        rect(c, 12, 7, 5, 2, 'r')                                -- jaws open
        set(c, 13, 7, 'W'); set(c, 15, 7, 'W'); set(c, 14, 8, 'W')
    else
        rect(c, 13, 7, 3, 1, 'K')                                -- mouth line
        set(c, 14, 8, 'W'); set(c, 16, 8, 'W')                   -- teeth
    end
    outline(c)
    return rows(c)
end
defs['piranha'] = { piranha(false, false), piranha(true, false), piranha(false, true) }

-- STONE GUARDIAN (the jungle's Shade, 24 x 32): an old mossy temple statue.
-- 1 asleep (eyes dark), 2-3 walking, 4 roaring (red eyes, mouth open)
local function guardian(pose)
    local c = canvas(24, 32)
    -- legs (bottom rows): walking frames step
    local legA, legB = 7, 14
    if pose == 'walk1' then legA, legB = 6, 15 elseif pose == 'walk2' then legA, legB = 8, 13 end
    rect(c, legA, 24, 4, 8, 'd'); rect(c, legA, 24, 1, 8, 'g')
    rect(c, legB, 24, 4, 8, 'd'); rect(c, legB + 3, 24, 1, 8, 'D')
    -- body block with carved lines
    rect(c, 5, 11, 15, 14, 'd')
    rect(c, 5, 11, 2, 14, 'g'); rect(c, 18, 11, 2, 14, 'D')
    rect(c, 9, 15, 7, 1, 'D'); rect(c, 9, 19, 7, 1, 'D'); rect(c, 12, 15, 1, 5, 'D')
    set(c, 12, 17, 'T'); set(c, 11, 17, 'T'); set(c, 13, 17, 'T')
    -- arms
    rect(c, 2, 12, 3, 10, 'd'); rect(c, 2, 12, 1, 10, 'g')
    rect(c, 20, 12, 3, 10, 'd'); rect(c, 22, 12, 1, 10, 'D')
    rect(c, 2, 21, 3, 2, 'g'); rect(c, 20, 21, 3, 2, 'g')        -- fists
    -- head
    rect(c, 7, 2, 12, 9, 'd')
    rect(c, 7, 2, 2, 9, 'g'); rect(c, 17, 2, 2, 9, 'D')
    rect(c, 9, 4, 9, 1, 'D')                                     -- heavy brow
    local eye = (pose == 'sleep') and 'D' or ((pose == 'roar') and 'R' or 'L')
    rect(c, 12, 6, 2, 1, eye); rect(c, 15, 6, 2, 1, eye)
    if pose == 'roar' then
        rect(c, 11, 8, 6, 2, 'r'); set(c, 12, 8, 'W'); set(c, 14, 8, 'W'); set(c, 16, 8, 'W')
    else
        rect(c, 12, 9, 5, 1, 'D')                                -- closed stone mouth
    end
    -- moss and vines over the stone
    rect(c, 7, 1, 10, 1, 'G'); rect(c, 8, 2, 4, 1, 'L'); set(c, 14, 2, 'G')
    set(c, 8, 3, 'G'); set(c, 8, 4, 'G'); set(c, 7, 5, 'j')
    rect(c, 5, 10, 5, 1, 'G'); rect(c, 15, 10, 5, 1, 'G'); set(c, 6, 11, 'L'); set(c, 18, 11, 'G')
    set(c, 2, 11, 'G'); set(c, 3, 11, 'L'); set(c, 21, 11, 'G')
    set(c, 6, 13, 'G'); set(c, 6, 14, 'j'); set(c, 19, 16, 'G'); set(c, 19, 17, 'j')
    outline(c)
    return rows(c)
end
defs['guardian'] = { guardian('sleep'), guardian('walk1'), guardian('walk2'), guardian('roar') }
