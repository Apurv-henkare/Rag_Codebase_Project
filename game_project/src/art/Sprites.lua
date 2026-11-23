--[[
    Inflate - Sprites
    Every sprite in the game, drawn as text grids using Palette letters.
    '.' = transparent. Each sprite is a list of frames.

    The ball is generated (round pixel shapes are hard to type by hand and
    must stay consistent across 3 sizes x 3 squash frames).
]]

Sprites = {}

local defs = {}
Sprites.defs = defs

---------------------------------------------------------------------------
-- TILES (16 x 16)
---------------------------------------------------------------------------

local DIRT = {
    "nnnnnnnnnnnnnnnn",
    "nnnbnnnnnnnnnnnn",
    "nnbbnnnnnnnnnbnn",
    "nnnnnnnnnnnnbbnn",
    "nnnnnnnObnnnnnnn",
    "nnnnnnnbbnnnnnnn",
    "nbnnnnnnnnnnnnnn",
    "nnnnnnnnnnbnnnnn",
    "nnnnnnnnnbbnnnnn",
    "nnnnbnnnnnnnnnnn",
    "nnnbbnnnnnnnnObn",
    "nnnnnnnnnnnnnbbn",
    "nnnnnnnnbnnnnnnn",
    "nnnnnnnnnnnnnnnn",
    "nnnnnnnnnnnnbnnn",
    "nnnnnnnnnnnnnnnn",
}

defs['ground'] = { DIRT }

defs['ground-top'] = {{
    "LLLLLLLLLLLLLLLL",
    "GLLGGLLLGLLGGLLG",
    "GGGGGGGGGGGGGGGG",
    "GTGGGTGGGGTGGGTG",
    "TbTTTbTTbTTbTTbT",
    "nnbnnnnnnnbnnnnn",
    DIRT[7], DIRT[8], DIRT[9], DIRT[10], DIRT[11],
    DIRT[12], DIRT[13], DIRT[14], DIRT[15], DIRT[16],
}}

defs['stone'] = {{
    "gggggggKgggggggK",
    "gddddddKgddddddK",
    "gddddddKgddddddK",
    "gddddddKgddddddK",
    "gddddddKgddddddK",
    "gddddddKgddddddK",
    "gDDDDDDKgDDDDDDK",
    "KKKKKKKKKKKKKKKK",
    "gggKgggggggKgggg",
    "dddKgddddddKgddd",
    "dddKgddddddKgddd",
    "dddKgddddddKgddd",
    "dddKgddddddKgddd",
    "dddKgddddddKgddd",
    "DDDKgDDDDDDKgDDD",
    "KKKKKKKKKKKKKKKK",
}}

-- cave rock (used instead of grass/dirt in cave levels)
local ROCK = {
    "DDDDDDdDDDDDDDDD",
    "DDdDDDDDDDDKDDDD",
    "DDDDDDDDDDKDDDDD",
    "DDDDKDDDDDDDDdDD",
    "DDDKDDDDDDDDDDDD",
    "DDDDDDDDdDDDDDDD",
    "DdDDDDDDDDDDDDDD",
    "DDDDDDDDDDDDDKDD",
    "DDDDDDDdDDDDKDDD",
    "DDDKDDDDDDDDDDDD",
    "DDKDDDDDDDDDDDdD",
    "DDDDDDDDDDDDDDDD",
    "DDDDDDdDDDDDDDDD",
    "DDDDDDDDDDKDDDDD",
    "DdDDDDDDDKDDDDDD",
    "DDDDDDDDDDDDDDDD",
}
defs['rock'] = { ROCK }
defs['rock-top'] = {{
    "dgdddgddddgdddgd",
    "dddddddddddddddd",
    "DdDDDdDDdDDDdDDD",
    ROCK[4], ROCK[5], ROCK[6], ROCK[7], ROCK[8], ROCK[9], ROCK[10],
    ROCK[11], ROCK[12], ROCK[13], ROCK[14], ROCK[15], ROCK[16],
}}

-- locked door (opens with a key); stacks vertically
defs['door'] = {{
    "KKKKKKKKKKKKKKKK",
    "KnnbnnnnnnnnbnnK",
    "KnOnnnnnnnnnnOnK",
    "KnnbnnnnnnnnbnnK",
    "KnnbnnnnnnnnbnnK",
    "KbbbbbbbbbbbbbbK",
    "KnnnnKKKKKKnnnnK",
    "KnnnnKYYYOKnnnnK",
    "KnnnnKYKKOKnnnnK",
    "KnnnnKYYKOKnnnnK",
    "KnnnnKOOOOKnnnnK",
    "KnnnnKKKKKKnnnnK",
    "KbbbbbbbbbbbbbbK",
    "KnnbnnnnnnnnbnnK",
    "KnnbnnnnnnnnbnnK",
    "KKKKKKKKKKKKKKKK",
}}

-- breakable by the Big ball
defs['cracked'] = {{
    "gggggggggggggggD",
    "gdddddKgdddddddD",
    "gdddddKgdddddddD",
    "gddddddKgddddddD",
    "gddddddKgddddddD",
    "gdddddKgdddddddD",
    "gddddKKKKgdddddD",
    "gddddKgddKgddddD",
    "gdddKgddddKKgddD",
    "gdddKgdddddddKgD",
    "gddddKgddddddddD",
    "gddddKgddddddddD",
    "gdddKgdddddddddD",
    "gdddKgdddddddddD",
    "gddddddddddddddD",
    "DDDDDDDDDDDDDDDD",
}}

-- two spikes on the bottom half of the tile
local SPIKE = {
    "...KK...",
    "..KWdK..",
    "..KgdK..",
    ".KWgddK.",
    ".KggddK.",
    "KWggdddK",
    "KgggdddK",
    "DDDDDDDD",
}
local spikes = {}
for i = 1, 8 do spikes[i] = "................" end
for i = 1, 8 do spikes[8 + i] = SPIKE[i] .. SPIKE[i] end
defs['spikes'] = { spikes }

---------------------------------------------------------------------------
-- FACTORY THEME (level 9 "Windworks"): metal floors, steel panels, fans
---------------------------------------------------------------------------

-- riveted panel h rows tall: light top/left edge, dark bottom/right edge, 4 rivets
local function panelGrid(body, light, dark, h)
    h = h or 16
    local rows = {}
    for y = 0, h - 1 do
        local row = {}
        for x = 0, 15 do
            local ch = body
            if x == 15 or y == h - 1 then ch = dark
            elseif x == 0 or y == 0 then ch = light end
            row[x + 1] = ch
        end
        rows[y + 1] = row
    end
    for _, p in ipairs({{2, 2}, {12, 2}, {2, h - 4}, {12, h - 4}}) do
        rows[p[2] + 1][p[1] + 1] = light      -- rivet: light dot ...
        rows[p[2] + 2][p[1] + 2] = 'K'        -- ... with a dark shadow
    end
    for y = 1, h do rows[y] = table.concat(rows[y]) end
    return rows
end

defs['metal'] = { panelGrid('d', 'g', 'D') }          -- factory floor (inside)
defs['steel'] = { panelGrid('T', 'S', 'D') }          -- teal steel block (= in factory levels)

-- factory floor surface: yellow / black hazard stripes on a metal panel
local metalTop = {
    "YYKKYYKKYYKKYYKK",
    "YKKYYKKYYKKYYKKY",
    "KKYYKKYYKKYYKKYY",
    "KKKKKKKKKKKKKKKK",
}
for _, row in ipairs(panelGrid('d', 'g', 'D', 12)) do metalTop[#metalTop + 1] = row end
defs['metal-top'] = { metalTop }

-- fan blocks (solid). A round fan with 3 blades behind a grille that glows
-- cyan while the fan blows. side = false: floor vent, grille on top (blows up).
-- side = true: wall blower, grille on the right (blows right; mirrored for left).
local TWO_PI = math.pi * 2
local function fanGrid(angle, on, side)
    local rows = {}
    for y = 0, 15 do
        local row = {}
        for x = 0, 15 do
            local ch = 'D'
            if x == 15 or y == 15 then ch = 'K'
            elseif x == 0 or y == 0 then ch = 'd' end
            row[x + 1] = ch
        end
        rows[y + 1] = row
    end

    -- grille: dark slats with glowing air between them
    local glow = on and 'C' or 'd'
    if side then
        for y = 1, 14 do
            rows[y + 1][13 + 1] = (y % 2 == 0) and 'K' or glow
            rows[y + 1][14 + 1] = (y % 2 == 0) and 'K' or glow
            rows[y + 1][15 + 1] = 'g'
        end
    else
        for x = 1, 14 do
            rows[1 + 1][x + 1] = (x % 2 == 0) and 'K' or glow
            rows[2 + 1][x + 1] = (x % 2 == 0) and 'K' or glow
        end
        for x = 0, 15 do rows[0 + 1][x + 1] = 'g' end
    end

    -- the fan
    local cx, cy = side and 6.5 or 7.5, side and 7.5 or 9.5
    for y = 0, 15 do
        for x = 0, 15 do
            local dx, dy = x + 0.5 - cx, y + 0.5 - cy
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist <= 5 then
                local ch = 'K'
                if dist > 4.1 then
                    ch = 'K'                                    -- housing ring
                elseif dist <= 1.2 then
                    ch = 'Y'                                    -- hub
                else
                    local a = math.atan2(dy, dx)
                    for k = 0, 2 do
                        local d = (a - angle - k * TWO_PI / 3) % TWO_PI
                        if d > math.pi then d = TWO_PI - d end
                        if d < 0.5 then ch = (d < 0.28) and 'g' or 'd' end
                    end
                end
                rows[y + 1][x + 1] = ch
            end
        end
    end
    for y = 1, 16 do rows[y] = table.concat(rows[y]) end
    return rows
end

-- frames 1-4: blowing (blades turn 30 degrees per frame), 5-8: switched off
local function fanFrames(side)
    local frames = {}
    for _, on in ipairs({true, false}) do
        for i = 0, 3 do frames[#frames + 1] = fanGrid(i * math.pi / 6, on, side) end
    end
    return frames
end
defs['vent'] = fanFrames(false)
defs['blower-r'] = fanFrames(true)
defs['blower-l'] = {}
for i, frame in ipairs(defs['blower-r']) do
    local m = {}
    for y, row in ipairs(frame) do m[y] = row:reverse() end
    defs['blower-l'][i] = m
end

---------------------------------------------------------------------------
-- RUINS THEME (level 10 "Sunken Gardens"): old stone, sand, carved blocks
---------------------------------------------------------------------------

-- old stone bricks: two courses with offset joints, a few spots of moss
local function ruinGrid()
    local rows = {}
    for y = 0, 15 do
        local row = {}
        for x = 0, 15 do
            local ch = 'D'
            if y == 7 or y == 15 then ch = 'K'                         -- mortar
            elseif y < 7 and x == 10 then ch = 'K'                     -- joints
            elseif y > 7 and x == 2 then ch = 'K'
            elseif y == 0 or y == 8 then ch = 'd' end                  -- brick top edge
            row[x + 1] = ch
        end
        rows[y + 1] = row
    end
    for _, p in ipairs({{4, 5}, {5, 5}, {5, 4}, {12, 13}, {13, 13}, {13, 12}, {7, 10}}) do
        rows[p[2] + 1][p[1] + 1] = 'G'
    end
    rows[5][6] = 'L'
    for y = 1, 16 do rows[y] = table.concat(rows[y]) end
    return rows
end
local RUIN = ruinGrid()
defs['ruin'] = { RUIN }

-- sand over old stone (ground surface in the ruins)
local ruinTop = {
    "YYYYWYYYYYYYYWYY",
    "YOYYYYYOYYYYOYYY",
    "OOnOOOOOnOOOOOnO",
    "nbnnnbnnnnbnnnbn",
}
for y = 5, 16 do ruinTop[#ruinTop + 1] = RUIN[y] end
defs['ruin-top'] = { ruinTop }

-- carved block (= in the ruins): bevelled stone, a carved square, a glowing rune
local function carvedGrid()
    local rows = {}
    for y = 0, 15 do
        local row = {}
        for x = 0, 15 do
            local ch = 'd'
            if x == 15 or y == 15 then ch = 'K'
            elseif x == 0 or y == 0 then ch = 'g'
            elseif x == 14 or y == 14 then ch = 'D'
            elseif x >= 3 and x <= 12 and y >= 3 and y <= 12
                and (x == 3 or x == 12 or y == 3 or y == 12) then ch = 'D'   -- carved groove
            elseif (x == 7 or x == 8) and (y == 7 or y == 8) then ch = 'C'   -- rune
            end
            row[x + 1] = ch
        end
        rows[y + 1] = row
    end
    for _, x in ipairs({2, 3, 9, 10, 11}) do rows[1][x + 1] = 'G' end      -- moss on top
    for _, x in ipairs({3, 10}) do rows[2][x + 1] = 'G' end
    for y = 1, 16 do rows[y] = table.concat(rows[y]) end
    return rows
end
defs['carved'] = { carvedGrid() }

-- bubble stream vent: a little pile of rocks with a hole (sits on the floor)
defs['bubble-vent'] = {{
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
    "......KKKK......",
    "....KKDddDKK....",
    "...KDdgKKgdDK...",
    "..KDddKKKKddDK..",
    ".KDDdddKKdddDDK.",
    "KKKKKKKKKKKKKKKK",
}}

---------------------------------------------------------------------------
-- OBJECTS
---------------------------------------------------------------------------

-- air pump: frame 1 idle, frame 2 handle pushed down
local PUMP_BODY = {
    "....KKKKKKKK....",
    "....KgWggddK....",
    "....KgCCCCdK....",
    "....KgCWCCdK....",
    "....KgCCCCdK....",
    "....KgggdddK....",
    "....KgggdddK....",
    "..KKKKKKKKKKKK..",
    "..KRRRRRRRRRrK..",
    "..KKKKKKKKKKKK..",
}
local function pumpFrame(top)
    local f = {}
    for i = 1, #top do f[#f + 1] = top[i] end
    for i = 1, #PUMP_BODY do f[#f + 1] = PUMP_BODY[i] end
    return f
end
defs['pump'] = {
    pumpFrame({
        "................",
        ".....KKKKKK.....",
        ".....KYYYYK.....",
        ".....KKKKKK.....",
        ".......KK.......",
        ".......KK.......",
    }),
    pumpFrame({
        "................",
        "................",
        "................",
        ".....KKKKKK.....",
        ".....KYYYYK.....",
        ".....KKKKKK.....",
    }),
}

-- gem (8 x 8), frame 2 = sparkle
defs['gem'] = {
    {
        "..KKKK..",
        ".KWYYYK.",
        "KWYYYYOK",
        "KYYYYOOK",
        ".KYYOOK.",
        "..KYOK..",
        "...KK...",
        "........",
    },
    {
        "..KKKK..",
        ".KYYYWK.",
        "KYYYYWOK",
        "KYYYYOOK",
        ".KYYOOK.",
        "..KYOK..",
        "...KK...",
        "........",
    },
}

-- goal flag (16 x 32), 2 waving frames
local function flagFrame(cloth)
    local f = {
        "................",
        ".KYWK...........",
        ".KYYK...........",
        "..KK............",
    }
    for i = 1, #cloth do f[#f + 1] = cloth[i] end
    while #f < 30 do f[#f + 1] = ".KgdK..........." end
    f[#f + 1] = "KKKKKKK........."
    f[#f + 1] = "KdddddK........."
    return f
end
defs['flag'] = {
    flagFrame({
        ".KgdKKKKKKKKK...",
        ".KgdKYYYYYYYK...",
        ".KgdKYYWYYYOK...",
        ".KgdKYYYYYOOK...",
        ".KgdKYYYYOOOK...",
        ".KgdKOOOOOOOK...",
        ".KgdKKKKKKKKK...",
    }),
    flagFrame({
        ".KgdKKKKKKKK....",
        ".KgdKYYYYYYKK...",
        ".KgdKYYWYYYYK...",
        ".KgdKYYYYYOOK...",
        ".KgdKYYYYOOOK...",
        ".KgdKOOOOOOKK...",
        ".KgdKKKKKKKK....",
    }),
}

-- spiky crawler enemy (16 x 16), 2 walking frames, faces right
local CRAWLER_TOP = {
    "................",
    "....K..K..K.....",
    "...KWKKWKKWK....",
    "...KWgKWgKWgK...",
    "...KKKKKKKKKK...",
    "..KggggggggggK..",
    ".KgddddddddddgK.",
    ".KgdddddddWWWdK.",
    ".KddddddddWKKdK.",
    "KdddddddddWKKddK",
    "KDddddddddWWWddK",
    "KDDddddddddddddK",
    "KDDDDDDDDDDDDDDK",
    ".KKKKKKKKKKKKKK.",
}
local function crawlerFrame(feet)
    local f = {}
    for i = 1, #CRAWLER_TOP do f[i] = CRAWLER_TOP[i] end
    f[#f + 1] = feet
    f[#f + 1] = "................"
    return f
end
-- upside-down copy of a grid (for the stunned crawler)
local function flipRows(grid)
    local out = {}
    for i = #grid, 1, -1 do out[#out + 1] = grid[i] end
    return out
end

local CRAWLER_WALK1 = crawlerFrame("..KK.......KK...")
local CRAWLER_WALK2 = crawlerFrame("...KK.....KK....")

-- frames: 1-2 walk, 3 stunned (flipped over), 4 squashed
defs['crawler'] = {
    CRAWLER_WALK1,
    CRAWLER_WALK2,
    flipRows(CRAWLER_WALK1),
    {
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
        "....K...K...K...",
        "..KKWKKKWKKKWKK.",
        ".KggggggggggggK.",
        "KDddddddKdKdddDK",
        ".KKKKKKKKKKKKKK.",
        "................",
    },
}

-- buzzer: small flying enemy (16 x 16), faces right. 1-2 wings flapping, 3 squashed
local BUZZER_BODY = {
    "..KKKKKKKKKK....",
    ".KYYYYYYYYYYK...",
    "KYYOOOOOWWWOOK..",
    "KYOOOOOOWKKOOK..",
    "KKKKKKKKWKKKKK..",
    "KOOOOOOOOWWOOK..",
    ".KOOOOOOOOOOK...",
    "..KKKKKKKKKK....",
    ".......KK.......",
    "........K.......",
    "................",
    "................",
}
local function buzzerFrame(wings)
    local f = {}
    for i = 1, #wings do f[#f + 1] = wings[i] end
    for i = 1, #BUZZER_BODY do f[#f + 1] = BUZZER_BODY[i] end
    return f
end
defs['buzzer'] = {
    buzzerFrame({
        "................",
        "..KKK....KKK....",
        ".KWWgK..KWWgK...",
        ".KWggK..KWggK...",
    }),
    buzzerFrame({
        "................",
        "................",
        "..KKK....KKK....",
        ".KWWgK..KWWgK...",
    }),
    {
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
        "................",
        "................",
        "..KKKKKKKKKK....",
        ".KOOOOKKOOOOK...",
        "KOOOOOOOOOOOOK..",
        ".KKKKKKKKKKKK...",
    },
}

-- FACTORY ENEMIES: same frame layout as the crawler / buzzer they replace

-- spark bot (replaces the crawler): little robot with a crackling spark on its
-- antenna, cyan eye, copper treads. 1-2 rolling, 3 knocked over, 4 squashed
local SPARKBOT_TOP = {
    "................",
    "......Y.Y.......",
    ".......W........",
    "......Y.Y.......",
    ".......K........",
    "....KKKKKKKK....",
    "...KggggggggK...",
    "..KgddddddCCdK..",
    "..KgddddddCKdK..",
    "..KddddddddddK..",
    "..KDDDDDDDDDDK..",
    ".KKKKKKKKKKKKKK.",
}
-- like the crawler: the bottom of the treads is sprite row 15, row 16 empty
local function sparkbotFrame(tread)
    local f = { "................" }
    for i = 1, #SPARKBOT_TOP do f[#f + 1] = SPARKBOT_TOP[i] end
    f[#f + 1] = tread
    f[#f + 1] = ".KKKKKKKKKKKKKK."
    f[#f + 1] = "................"
    return f
end
local SPARKBOT_ROLL1 = sparkbotFrame(".KnOnnOnnOnnOnK.")
local SPARKBOT_ROLL2 = sparkbotFrame(".KnnOnnOnnOnnOK.")

defs['sparkbot'] = {
    SPARKBOT_ROLL1,
    SPARKBOT_ROLL2,
    flipRows(SPARKBOT_ROLL1),
    {
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
        ".......Y........",
        "...KKKKKKKKKK...",
        "..KgddCKCddddK..",
        ".KDDDDDDDDDDDDK.",
        ".KKKKKKKKKKKKKK.",
        "................",
    },
}

-- drone (replaces the buzzer): flying robot with a spinning rotor.
-- 1-2 rotor turning, 3 squashed
local DRONE_BODY = {
    "..KKKKKKKKKK....",
    ".KggggggggggK...",
    "KgddddddCCCdK...",
    "KgddddddCWCdK...",
    "KDddddddCCCdK...",
    "KDDDDDDDDDDDK...",
    ".KKKKKKKKKKK....",
    "..KO......OK....",
    "..K........K....",
    "................",
    "................",
    "................",
}
local function droneFrame(rotor)
    local f = {}
    for i = 1, #rotor do f[#f + 1] = rotor[i] end
    for i = 1, #DRONE_BODY do f[#f + 1] = DRONE_BODY[i] end
    return f
end
defs['drone'] = {
    droneFrame({
        "................",
        "KKKKKKKKKKKKK...",
        "KggggggggggdK...",
        ".....KKK........",
    }),
    droneFrame({
        "................",
        "...KKKKKKK......",
        "...KgggggK......",
        ".....KKK........",
    }),
    {
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
        "................",
        "................",
        "..KKKKKKKKKK....",
        ".KggddKKddCdK...",
        "KDDDDDDDDDDDDK..",
        ".KKKKKKKKKKKK...",
    },
}

-- RUINS ENEMIES: same frame layout as the crawler / buzzer they replace

-- crab (replaces the crawler): red shell, orange claws, eyes on stalks.
-- 1-2 walking, 3 knocked over, 4 squashed. Legs are on row 15 like the crawler.
local CRAB_TOP = {
    "................",
    "................",
    "................",
    ".KK..........KK.",
    "KOOK........KOOK",
    "KRRK.KK..KK.KRRK",
    ".KRK.KW..WK.KRK.",
    "..KRKKKKKKKKRK..",
    "..KROOOOOOOORK..",
    ".KRROOOOOOOORRK.",
    ".KRRRRRRRRRRRRK.",
    ".KrRRRRRRRRRRrK.",
    "..KrrrrrrrrrrK..",
    "...KKKKKKKKKK...",
}
local function crabFrame(legs)
    local f = {}
    for i = 1, #CRAB_TOP do f[i] = CRAB_TOP[i] end
    f[#f + 1] = legs
    f[#f + 1] = "................"
    return f
end
local CRAB_WALK1 = crabFrame("..K.K.K..K.K.K..")
local CRAB_WALK2 = crabFrame(".K.K.K....K.K.K.")
defs['crab'] = {
    CRAB_WALK1,
    CRAB_WALK2,
    flipRows(CRAB_WALK1),
    {
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
        "................",
        ".KK..........KK.",
        "KOOKKKKKKKKKKOOK",
        "KrRRRRRRRRRRRRrK",
        ".KKKKKKKKKKKKKK.",
        "................",
    },
}

-- jellyfish (replaces the buzzer): glowing bell that pulses, wavy tentacles.
-- 1-2 pulsing, 3 squashed
defs['jelly'] = {
    {
        "................",
        "................",
        "................",
        "....KKKKKK......",
        "..KKCCCWWCKK....",
        ".KCCCCCCWWCCK...",
        "KCCCCCCCCCCCCK..",
        "KCSCCSCCSCCSCK..",
        "KKKKKKKKKKKKKK..",
        ".S.S.S..S.S.S...",
        "..S.S..S..S.S...",
        ".S..S.S..S..S...",
        "..S..S..S..S....",
        "................",
        "................",
        "................",
    },
    {
        "................",
        "................",
        ".....KKKK.......",
        "....KCCWWK......",
        "...KCCCCWWK.....",
        "...KCCCCCCK.....",
        "..KCCCCCCCCK....",
        "..KCSCCSCCSK....",
        "..KKKKKKKKKK....",
        "...S.S.S.S......",
        "..S.S.S.S.S.....",
        "...S.S.S.S......",
        "..S.S.S.S.S.....",
        "................",
        "................",
        "................",
    },
    {
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
        "................",
        "................",
        "..KKKKKKKKKK....",
        ".KCCSCCSCCSCK...",
        "KCCCCCCCCCCCCK..",
        ".KKKKKKKKKKKK...",
    },
}

---------------------------------------------------------------------------
-- GROVE THEME (level 11 "Lantern Grove"): roots, bark, planks, plates, gates
---------------------------------------------------------------------------

-- tree bark: vertical grain with a knot
local BARK = {
    "nbnnnbnnnnbnnnbn",
    "nbnnnbnnnnnbnnbn",
    "nbnnbnnnnnnbnnbn",
    "nnbnbnnnnnnbnnnb",
    "nnbnbnnbbnnbnnnb",
    "nnbnnbnbKbnnbnnb",
    "nnbnnbnnbbnnbnnb",
    "nbnnnbnnnnnnbnnb",
    "nbnnnbnnnnnbnnbn",
    "bnnnnnbnnnnbnnbn",
    "bnnnnnbnnnbnnnbn",
    "bnnOnnbnnnbnnbnn",
    "nbnnnnbnnnbnnbnn",
    "nbnnnbnnnnnbnnbn",
    "nbnnnbnnnnnbnnbn",
    "nbnnnbnnnnbnnnbn",
}
defs['bark'] = { BARK }

-- moss and little roots over bark (ground surface in the grove)
local rootTop = {
    "LLGLLLLGLLLLGLLL",
    "GGGGLGGGGGGLGGGG",
    "GTGGGGTGGTGGGGTG",
    "TbTTbTTnbTTbTTbT",
}
for y = 5, 16 do rootTop[#rootTop + 1] = BARK[y] end
defs['root-top'] = { rootTop }

-- wooden planks (= in the grove): two boards with nails, offset joints
defs['planks'] = {{
    "OOOOOOOOOOOOOOOb",
    "nnnnnnnnnnnnnnnb",
    "nKnnnbbnnnnnnKnb",
    "nnnnnnnnnbbnnnnb",
    "nnbbnnnnnnnnnnnb",
    "nnnnnnnnnnnnnnnb",
    "bbbbbbbbbbbbbbbb",
    "KKKKKKKKKKKKKKKK",
    "OOOOOOObOOOOOOOO",
    "nnnnnnnbnnnnnnnn",
    "nnnKnnnbnnnnKnnn",
    "nnnnnnnbnbbnnnnn",
    "nbbnnnnbnnnnnnnn",
    "nnnnnnnbnnnnnnnn",
    "bbbbbbbbbbbbbbbb",
    "KKKKKKKKKKKKKKKK",
}}

-- one colour per plate / gate group, so you can see which plate opens which gate
local GROUP_COLORS = { 'Y', 'C', 'L', 'R', 'O', 'W' }

-- gate: 1 closed (iron bars with a coloured rune), 2 open (faint corners only)
local function gateGrid(color, open)
    local rows = {}
    for y = 0, 15 do
        local row = {}
        for x = 0, 15 do
            local ch
            if open then
                ch = '.'
                local cx, cy = (x <= 1 or x >= 14), (y <= 1 or y >= 14)
                if (x == 0 or x == 15) and cy then ch = 'D' end
                if (y == 0 or y == 15) and cx then ch = 'D' end
            else
                ch = 'K'
                if x % 4 == 1 then ch = 'g' elseif x % 4 == 2 then ch = 'd' end   -- bars
                if y == 1 or y == 13 then ch = 'g' elseif y == 2 or y == 14 then ch = 'd' end
                if x >= 5 and x <= 10 and y >= 5 and y <= 10 then              -- rune plaque
                    ch = 'K'
                    if x >= 6 and x <= 9 and y >= 6 and y <= 9 then
                        ch = ((x == 7 or x == 8) or (y == 7 or y == 8)) and color or 'D'
                    end
                end
            end
            row[x + 1] = ch
        end
        rows[y + 1] = table.concat(row)
    end
    return rows
end

-- pressure plate: 1 up, 2 pressed down. Timer plates have a white clock dot
-- on each side.
local EMPTY_ROW = "................"
local function plateFrames(color, timer)
    local dot = timer and 'W' or 'g'
    local dotD = timer and 'W' or 'd'
    local up, down = {}, {}
    for i = 1, 11 do up[i] = EMPTY_ROW end
    up[12] = "..KKKKKKKKKKKK.."
    up[13] = "..K" .. dot .. "ggg" .. color .. color .. "ggg" .. dot .. "K.."
    up[14] = "..Kdddd" .. color .. color .. "ddddK.."
    up[15] = ".KKKKKKKKKKKKKK."
    up[16] = "KDDDDDDDDDDDDDDK"
    for i = 1, 13 do down[i] = EMPTY_ROW end
    down[14] = "..KKKKKKKKKKKK.."
    down[15] = ".KK" .. dotD .. "ddd" .. color .. color .. "ddd" .. dotD .. "KK."
    down[16] = "KDDDDDDDDDDDDDDK"
    return { up, down }
end

for i, color in ipairs(GROUP_COLORS) do
    defs['gate-' .. i] = { gateGrid(color, false), gateGrid(color, true) }
    defs['plate-' .. i] = plateFrames(color, false)
    defs['tplate-' .. i] = plateFrames(color, true)
end

-- hanging paper lantern (the glow is drawn by GameObject)
defs['lantern'] = {{
    ".......K........",
    ".......K........",
    "......KKK.......",
    ".....KbbbK......",
    "....KRRRRRK.....",
    "....KROYORK.....",
    "....KOYWYOK.....",
    "....KOYYYOK.....",
    "....KROYORK.....",
    "....KRRRRRK.....",
    ".....KbbbK......",
    "......KKK.......",
    ".......R........",
    ".......R........",
    "................",
    "................",
}}

-- GROVE ENEMIES: same frame layout as the crawler / buzzer they replace

-- hedgehog (replaces the crawler): spiky brown back, orange face.
-- 1-2 walking, 3 rolled over, 4 squashed. Feet on row 15 like the crawler.
local HEDGEHOG_TOP = {
    "................",
    "................",
    "....K.K.K.K.....",
    "...KbKbKbKbK....",
    "..KbnbnbnbnbK...",
    ".KbnbnbnbnbnbK..",
    ".KnbnbnbnbnbOOK.",
    "KbnbnbnbnbnOOOK.",
    "KnbnbnbnbnOOKOOK",
    "KbnbnbnbnbOOOOOK",
    "KnbnbnbnbOOOOOKK",
    ".KnnnnnnnOOOOK..",
    "..KnnnnnnnnnK...",
    "..KKKKKKKKKKK...",
}
local function hedgehogFrame(feet)
    local f = {}
    for i = 1, #HEDGEHOG_TOP do f[i] = HEDGEHOG_TOP[i] end
    f[#f + 1] = feet
    f[#f + 1] = EMPTY_ROW
    return f
end
local HEDGEHOG_WALK1 = hedgehogFrame("..KK......KK....")
local HEDGEHOG_WALK2 = hedgehogFrame("...KK....KK.....")
defs['hedgehog'] = {
    HEDGEHOG_WALK1,
    HEDGEHOG_WALK2,
    flipRows(HEDGEHOG_WALK1),
    {
        EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW,
        EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW,
        "...K.K.K.K.K....",
        "..KbnbnbnbnbOK..",
        ".KnbnbnbnbnOOOK.",
        "KbnbnbnbnbOOKOOK",
        ".KKKKKKKKKKKKKK.",
        EMPTY_ROW,
    },
}

-- moth (replaces the buzzer): pale wings with orange eye spots.
-- 1-2 flapping, 3 squashed
local function mothFrame(rows)
    local f = {}
    for i = 1, 16 do f[i] = rows[i] or EMPTY_ROW end
    return f
end
defs['moth'] = {
    mothFrame({
        "....K.....K.....",
        ".....K...K......",
        ".KKK..K.K..KKK..",
        "KgWgK.KKK.KgWgK.",
        "KgOgKKnnnKKgOgK.",
        "KggggKnYnKggggK.",
        ".KgggKnnnKgggK..",
        "..KKKKnYnKKKK...",
        "......KnK.......",
        ".......K........",
    }),
    mothFrame({
        "....K.....K.....",
        ".....K...K......",
        "......K.K.......",
        "......KKK.......",
        "..KKKKnnnKKKK...",
        ".KgggKnYnKgggK..",
        "KggOgKnnnKgOggK.",
        "KgWggKnYnKggWgK.",
        ".KKKK.KnK.KKKK..",
        ".......K........",
    }),
    mothFrame({
        nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
        "..KKK.KKK.KKK...",
        ".KgOgKnYnKgOgK..",
        "KggggKnnnKggggK.",
        ".KKKKKKKKKKKKK..",
    }),
}

---------------------------------------------------------------------------
-- ICE THEME (level 12 "Frostpeak"): snow, ice, icicles, moving platforms
---------------------------------------------------------------------------

-- blue-grey ice with light cracks and a few sparkles
local ICE = {
    "dddddddddddddddd",
    "ddSddddddddddddd",
    "dSdddddddWdddddd",
    "Sddddddddgdddddd",
    "dddddddddddddSdd",
    "ddddDdddddddSddd",
    "dddDdddddddSdddd",
    "ddDddddddddddddd",
    "dddddddSdddddddd",
    "ddddddSddddddddd",
    "dddddSdddddDdddd",
    "ddWddddddddDdddd",
    "ddgdddddddddDddd",
    "dddddddddddddddd",
    "dddddddddSdddddd",
    "ddddddddSddddddd",
}
defs['ice'] = { ICE }

-- snow cap over ice (ground surface in Frostpeak)
local snowTop = {
    "WWWWWWWWWWWWWWWW",
    "WWWWWWWWWWWWWWWW",
    "WWWgWWWWWWWWgWWW",
    "gWgggWWgWWWgggWg",
    "dgddgggdggggddgd",
}
for y = 6, 16 do snowTop[#snowTop + 1] = ICE[y] end
defs['snow-top'] = { snowTop }

-- ice brick (= in Frostpeak): bright block, shine on the top-left corner
local function iceBrickGrid()
    local rows = {}
    for y = 0, 15 do
        local row = {}
        for x = 0, 15 do
            local ch = 'S'
            if x == 15 or y == 15 then ch = 'D'
            elseif x == 14 or y == 14 then ch = 'T'
            elseif x == 0 or y == 0 then ch = 'C'
            elseif (x == 2 and (y == 2 or y == 3)) or (y == 2 and x == 3) then ch = 'W'
            elseif x + y == 19 and x >= 8 and x <= 12 then ch = 'C'                -- glint
            end
            row[x + 1] = ch
        end
        rows[y + 1] = table.concat(row)
    end
    return rows
end
defs['icebrick'] = { iceBrickGrid() }

-- copy of a grid with some letters swapped
local function recolor(grid, map)
    local out = {}
    for i = 1, #grid do
        out[i] = (grid[i]:gsub('.', function(ch) return map[ch] or ch end))
    end
    return out
end

-- cracked ice (C in Frostpeak): the cracked block in ice colours
defs['ice-cracked'] = { recolor(defs['cracked'][1], { g = 'C', d = 'S', D = 'T', K = 'D' }) }

-- icicles: three long icicles hanging from the ceiling above (a full tile)
local function icicleGrid()
    local rows = {}
    for y = 0, 15 do
        local row = {}
        for x = 0, 15 do row[x + 1] = '.' end
        rows[y + 1] = row
    end
    for x = 0, 15 do rows[1][x + 1] = 'T' end                       -- frozen to the ceiling
    for _, ic in ipairs({{3, 16}, {8, 12}, {12, 15}}) do            -- centre x, length
        local cx, len = ic[1], ic[2]
        for y = 1, len - 1 do
            local half = math.floor((len - y) / len * 2.4 + 0.5)
            for x = cx - half, cx + half do
                local ch = 'S'
                if x == cx - half or x == cx + half then ch = 'K'
                elseif x < cx then ch = 'W'
                elseif x == cx then ch = 'C' end
                if half == 0 then ch = 'C' end
                if x >= 0 and x <= 15 then rows[y + 1][x + 1] = ch end
            end
        end
    end
    for y = 1, 16 do rows[y] = table.concat(rows[y]) end
    return rows
end
defs['icicle'] = { icicleGrid() }

-- moving platform (16 x 8 pieces): 1 left end, 2 middle, 3 right end
local LIFT_LEFT = {
    "KKKKKKKKKKKKKKKK",
    "KWgKOOOOOOOOOOOO",
    "KgdKnnnnnnnnnnnn",
    "KgdKnnnnnbnnnnnn",
    "KgdKnnnnnnnnnnnn",
    "KddKbbbbbbbbbbbb",
    "KKKKKKKKKKKKKKKK",
    "..KK............",
}
local LIFT_RIGHT = {}
for i = 1, #LIFT_LEFT do LIFT_RIGHT[i] = LIFT_LEFT[i]:reverse() end
defs['lift'] = {
    LIFT_LEFT,
    {
        "KKKKKKKKKKKKKKKK",
        "OOOOOOOOOOOOOOOO",
        "nnnnnnnnnnnnnnnn",
        "nnnnnnnnnnnnbnnn",
        "nnnbnnnnnnnnnnnn",
        "bbbbbbbbbbbbbbbb",
        "KKKKKKKKKKKKKKKK",
        "................",
    },
    LIFT_RIGHT,
}

-- ICE ENEMIES: same frame layout as the crawler / buzzer they replace

-- penguin (replaces the crawler): waddles, orange beak and feet.
-- 1-2 walking, 3 on its back, 4 squashed. Feet on row 15 like the crawler.
local PENGUIN_TOP = {
    "................",
    "................",
    "......KKKK......",
    ".....KDDDDK.....",
    "....KDDDWWDK....",
    "....KDDWKWWK....",
    "....KDDWWWWOOK..",
    "...KDDDWWWWOK...",
    "..KDDDWWWWWWK...",
    "..KDDKWWWWWWK...",
    ".KDDDKWWWWWWK...",
    ".KDDKWWWWWWWK...",
    "..KKKWWWWWWgK...",
    "....KKKKKKKK....",
}
local function penguinFrame(feet)
    local f = {}
    for i = 1, #PENGUIN_TOP do f[i] = PENGUIN_TOP[i] end
    f[#f + 1] = feet
    f[#f + 1] = EMPTY_ROW
    return f
end
local PENGUIN_WALK1 = penguinFrame("....OO...OO.....")
local PENGUIN_WALK2 = penguinFrame(".....OO.OO......")
defs['penguin'] = {
    PENGUIN_WALK1,
    PENGUIN_WALK2,
    flipRows(PENGUIN_WALK1),
    {
        EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW,
        EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW,
        "....KKKKKKK.....",
        "..KDDDWWWKWOK...",
        ".KDDDWWWWWWWWK..",
        "..OOKKKKKKKKOO..",
        EMPTY_ROW,
    },
}

-- snow owl (replaces the buzzer): round and white, yellow eyes.
-- 1-2 wings up / down, 3 squashed
defs['owl'] = {
    {
        "................",
        "...KK.....KK....",
        "...KWKKKKKWK....",
        "KK.KWWWWWWWK.KK.",
        "KgKKWYYWYYWKKgK.",
        "KggKWYKWYKWKggK.",
        ".KgKWWWOWWWKgK..",
        "..KKWWWOWWWKK...",
        "...KWgWgWgWK....",
        "...KWWgWgWWK....",
        "....KWWWWWK.....",
        ".....KKKKK......",
        ".....O...O......",
        EMPTY_ROW, EMPTY_ROW, EMPTY_ROW,
    },
    {
        "................",
        "...KK.....KK....",
        "...KWKKKKKWK....",
        "...KWWWWWWWK....",
        "...KWYYWYYWK....",
        "...KWYKWYKWK....",
        "...KWWWOWWWK....",
        ".KKKWWWOWWWKKK..",
        "KggKWgWgWgWKggK.",
        "KgKKWWgWgWWKKgK.",
        "KK..KWWWWWK..KK.",
        ".....KKKKK......",
        ".....O...O......",
        EMPTY_ROW, EMPTY_ROW, EMPTY_ROW,
    },
    {
        EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW,
        EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW,
        "...KK.....KK....",
        ".KKWYKWOWYKWKK..",
        "KggWWWWWWWWWggK.",
        ".KKKKKKKKKKKKKK.",
    },
}

---------------------------------------------------------------------------
-- SPACE THEME (level 13 "Starfall"): floating rock, brass, gravity orbs
---------------------------------------------------------------------------

-- dark floating rock with glowing crystal veins
local ASTRO = {
    "DDDDDDDDDDDDDDDD",
    "DDKDDDDDDDDDDDDD",
    "DDDDDDDDDTDDDDDD",
    "DDDDDDDDTCDDDDDD",
    "DDDDDDDTCDDDDKDD",
    "DDDDDDTCDDDDDDDD",
    "DDDDDDTDDDDDDDDD",
    "DDKDDDDDDDDDDDDD",
    "DDDDDDDDDDDDDDDD",
    "DDDDDDDDDDDDTDDD",
    "DDDTDDDDDDDDCTDD",
    "DDDCTDDDDDDDDCDD",
    "DDDDCDDDDDKDDDDD",
    "DDDDDDDDDDDDDDDD",
    "DDDDDDKDDDDDDDDD",
    "DDDDDDDDDDDDDDDD",
}
defs['astro'] = { ASTRO }

-- rock surface (nothing above): a lighter crust
local astroTop = {
    "ddgddddgddddgddd",
    "dddddddddddddddd",
    "DdDDdDDDdDDdDDDd",
}
for y = 4, 16 do astroTop[#astroTop + 1] = ASTRO[y] end
defs['astro-top'] = { astroTop }

-- rock underside (nothing below): crust with crystal tips, the ball rolls
-- here upside down
local astroBottom = {}
for y = 1, 13 do astroBottom[y] = ASTRO[y] end
astroBottom[14] = "DdDDdDDDdDDdDDDd"
astroBottom[15] = "dddddddddddddddd"
astroBottom[16] = "dCddddCdddddCddd"
defs['astro-bottom'] = { astroBottom }

-- brass block (= in Starfall): riveted observatory panel
defs['brass'] = { panelGrid('O', 'Y', 'n') }

-- cracked rock (C in Starfall): the cracks glow cyan
defs['astro-cracked'] = { recolor(defs['cracked'][1], { g = 'd', d = 'D', D = 'K', K = 'C' }) }

-- spikes hanging from a ceiling (v in Starfall)
defs['spikes-down'] = { flipRows(defs['spikes'][1]) }

-- gravity orb: a ring with an arrow. up = cyan (flips gravity up),
-- down = yellow (flips it back). Frame 2: the ring sparkles.
local function orbFrame(up, sparkle)
    local ring = up and 'C' or 'Y'
    local rows = {}
    for y = 0, 15 do
        local row = {}
        for x = 0, 15 do
            local dx, dy = x - 7.5, y - 7.5
            local d = math.sqrt(dx * dx + dy * dy)
            local ch = '.'
            if d <= 7.3 then
                if d > 6.3 then ch = 'K'
                elseif d > 4.9 then
                    ch = ring
                    if sparkle and (x + y) % 5 == 0 then ch = 'W' end
                else ch = 'D' end
            end
            row[x + 1] = ch
        end
        rows[y + 1] = row
    end
    -- arrow pointing up (flipped below for the down orb)
    local arrow = {{7, 3}, {8, 3}, {6, 4}, {7, 4}, {8, 4}, {9, 4}, {5, 5}, {6, 5}, {9, 5}, {10, 5}}
    for y = 5, 11 do arrow[#arrow + 1] = {7, y}; arrow[#arrow + 1] = {8, y} end
    for _, p in ipairs(arrow) do rows[p[2] + 1][p[1] + 1] = 'W' end
    for y = 1, 16 do rows[y] = table.concat(rows[y]) end
    if not up then rows = flipRows(rows) end
    return rows
end
defs['orb-up']   = { orbFrame(true, false), orbFrame(true, true) }
defs['orb-down'] = { orbFrame(false, false), orbFrame(false, true) }

-- SPACE ENEMIES: same frame layout as the crawler / buzzer they replace

-- space slug (replaces the crawler): glowing green, eyes on stalks.
-- 1-2 crawling, 3 flipped over, 4 squashed. Bottom on row 15 like the crawler.
local SLUG_TOP = {
    "................",
    "................",
    "................",
    "................",
    "..........K.K...",
    ".........KWKWK..",
    "..........K.K...",
    "..........K.K...",
    "....KKKKKKKKK...",
    "...KLLLLLLLLLK..",
    "..KLGLLGLLLLLLK.",
    ".KGGGGGGGGGGGGK.",
    ".KGTGGGTGGGTGGK.",
    "KTTTTTTTTTTTTTK.",
}
local function slugFrame(base)
    local f = {}
    for i = 1, #SLUG_TOP do f[i] = SLUG_TOP[i] end
    f[#f + 1] = base
    f[#f + 1] = EMPTY_ROW
    return f
end
local SLUG_WALK1 = slugFrame("KKKKKKKKKKKKKKK.")
local SLUG_WALK2 = slugFrame(".KKKKKKKKKKKKKKK")
defs['slug'] = {
    SLUG_WALK1,
    SLUG_WALK2,
    flipRows(SLUG_WALK1),
    {
        EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW,
        EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW,
        "....KKKKKKKKK...",
        "..KLGGLGGLGGGK..",
        "KTTTTTTTTTTTTTTK",
        EMPTY_ROW,
    },
}

-- spark star (replaces the buzzer): a little star that spins.
-- 1-2 spinning, 3 squashed
local function starFrame(rows)
    local f = {}
    for i = 1, 16 do f[i] = rows[i] or EMPTY_ROW end
    return f
end
defs['sparkstar'] = {
    starFrame({
        EMPTY_ROW,
        EMPTY_ROW,
        "......K.........",
        ".....KYK........",
        ".....KYK........",
        "..KKKKYKKKK.....",
        ".KYYYYWYYYYK....",
        "..KKKKYKKKK.....",
        ".....KYK........",
        ".....KYK........",
        "......K.........",
    }),
    starFrame({
        EMPTY_ROW,
        EMPTY_ROW,
        "..O.......O.....",
        "...O.....O......",
        "....O.K.O.......",
        ".....KYK........",
        "....KYWYK.......",
        ".....KYK........",
        "....O.K.O.......",
        "...O.....O......",
        "..O.......O.....",
    }),
    starFrame({
        nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
        ".....KKK........",
        "..KKKYWYKKK.....",
        ".KYYYYYYYYYK....",
        "..KKKKKKKKK.....",
    }),
}

---------------------------------------------------------------------------
-- CRYSTAL CAVE (level 14)
---------------------------------------------------------------------------

-- CRYSTAL CAVE (level 14): deep purple rock with crystal flecks
defs['crystal-rock'] = {
    {
        "pppppppppppppppp",
        "pppppppppppppppp",
        "ppppppppppppDppp",
        "ppppppppppppDppp",
        "ppppvppppppppppp",
        "ppKpppKppppppppp",
        "pppKKppKpppppppp",
        "pppppKpKpppppppp",
        "pppppDppKppppppp",
        "pppppDpppppDpppp",
        "ppDppppppppDvppp",
        "ppDppppppppppppp",
        "pppppDpvpppppppp",
        "pppppDDppppppppp",
        "pppppppppppppppp",
        "pppppppppppppppp",
    },
}

-- rock surface: a glittering crystal crust
defs['crystal-top'] = {
    {
        "vvWvvvvvvvvvWvvv",
        "pvvpvvvpvvpvvvpv",
        "pppKppppppKppppp",
        "ppppppppppppDppp",
        "ppppvppppppppppp",
        "ppKpppKppppppppp",
        "pppKKppKpppppppp",
        "pppppKpKpppppppp",
        "pppppDppKppppppp",
        "pppppDpppppDpppp",
        "ppDppppppppDvppp",
        "ppDppppppppppppp",
        "pppppDpvpppppppp",
        "pppppDDppppppppp",
        "pppppppppppppppp",
        "pppppppppppppppp",
    },
}

-- rock underside (ceilings): crust lit from below
defs['crystal-bottom'] = {
    {
        "pppppppppppppppp",
        "pppppppppppppppp",
        "ppppppppppppDppp",
        "ppppppppppppDppp",
        "ppppvppppppppppp",
        "ppKpppKppppppppp",
        "pppKKppKpppppppp",
        "pppppKpKpppppppp",
        "pppppDppKppppppp",
        "pppppDpppppDpppp",
        "ppDppppppppDvppp",
        "ppDppppppppppppp",
        "pppppDpvpppppppp",
        "pppKppppppKppppp",
        "pvppvvpppvpppvvp",
        "vvpvvvvpvvvvpvvv",
    },
}

-- amethyst block (= in level 14): a cut purple crystal
defs['amethyst'] = {
    {
        "WWWWWWWWWWWWWWWK",
        "vKvWvvWvvWvvWKvK",
        "vvKvvvvvvvvvKvpK",
        "vvvKvvvvvvvKvpvK",
        "vvvvKvvKvvKvpvpK",
        "vvvvvKKWKKvpvpvK",
        "vvvvvKWWvKpvpvpK",
        "vvvvKWWvvvKpvpvK",
        "vvvvvKvvvKpvpvpK",
        "vvvvvKKvKKvpvpvK",
        "vvvvKppKppKvpvpK",
        "vvvKpppppppKvpvK",
        "vvKpppppppppKvpK",
        "vKpppppppppppKvK",
        "vpppppppppppppKK",
        "KKKKKKKKKKKKKKKK",
    },
}

-- glowing crystal clusters (x / y / z in level 14): decoration with a soft glow
defs['cluster-purple'] = {
    {
        "................",
        "................",
        "........K.......",
        ".......KK.......",
        ".......KK.......",
        "......KWvK......",
        "......KWvK...K..",
        ".....KWvvpK..K..",
        "..K..KWvvpK.KK..",
        "..K..KWvvpKKWvK.",
        ".KvK.KWvvpKKWvK.",
        ".KWvKKWvvpKKWvK.",
        ".KWvKKWvvpKWvK..",
        ".KWvKKWvvpKWvK..",
        ".KWvKKWvvpKWvK..",
        "..KWvKWvvpKWvK..",
    },
}

defs['cluster-orange'] = {
    {
        "................",
        "................",
        "........K.......",
        ".......KK.......",
        ".......KK.......",
        "......KYOK......",
        "......KYOK...K..",
        ".....KYOOrK..K..",
        "..K..KYOOrK.KK..",
        "..K..KYOOrKKYOK.",
        ".KOK.KYOOrKKYOK.",
        ".KYOKKYOOrKKYOK.",
        ".KYOKKYOOrKYOK..",
        ".KYOKKYOOrKYOK..",
        ".KYOKKYOOrKYOK..",
        "..KYOKYOOrKYOK..",
    },
}

defs['cluster-silver'] = {
    {
        "................",
        "................",
        "........K.......",
        ".......KK.......",
        ".......KK.......",
        "......KWgK......",
        "......KWgK...K..",
        ".....KWggdK..K..",
        "..K..KWggdK.KK..",
        "..K..KWggdKKWgK.",
        ".KgK.KWggdKKWgK.",
        ".KWgKKWggdKKWgK.",
        ".KWgKKWggdKWgK..",
        ".KWgKKWggdKWgK..",
        ".KWgKKWggdKWgK..",
        "..KWgKWggdKWgK..",
    },
}

-- cave bat (replaces the buzzer in level 14): 1-2 flying, 3 squashed,
-- 4 hanging upside down from the ceiling (feet on row 5)
defs['bat'] = {
    {
        "................",
        "................",
        "................",
        "................",
        "K..........K....",
        "KK..K..K..KK....",
        "KpK.KKKK.KpK....",
        "KppKYppYKppK....",
        "KpppKppKpppK....",
        ".KKKppppKKK.....",
        "....KppK........",
        ".....KK.........",
        "................",
        "................",
        "................",
        "................",
    },
    {
        "................",
        "................",
        "................",
        "................",
        "................",
        "....K..K........",
        "...KKppKK.......",
        "KKKKYppYKKKK....",
        "KppKppppKppK....",
        "KpK.KppK.KpK....",
        "K...KKKK...K....",
        "................",
        "................",
        "................",
        "................",
        "................",
    },
    {
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
        "................",
        "................",
        "KKKKKKKKKKKK....",
        "KppYppppYppK....",
        ".KKKKKKKKKK.....",
        "................",
    },
    {
        "................",
        "................",
        "................",
        "................",
        "....K..K........",
        "...KKKKKK.......",
        "...KppppK.......",
        "..KpKppKpK......",
        "..KppKKppK......",
        "...KYppYK.......",
        "....KKKK........",
        "................",
        "................",
        "................",
        "................",
        "................",
    },
}

-- the Shade (level 14): can't be hurt, chases the ball. 24 x 32, faces right.
-- 1 asleep, 2-3 walking, 4 waking up (roar)
defs['shade'] = {
    {
        ".........K..............",
        ".........W..............",
        "........KvK..K..........",
        "........KvWK.W..........",
        ".....K..KvWKKvK.........",
        ".....W..KvWKKvWK........",
        "....KvK.KvWKKvWK........",
        "....KvWKKvWKKvWKKK......",
        "....KvWKKvWKKKddddKK....",
        "....KvWK...KddDDDDddK...",
        "....KvWKKKKdDDDDDDDDdK..",
        ".....KKddddDDDDDDDDDDK..",
        "....KddDDDDDDDDDDDDDDK..",
        "...KdDDDDDDDDDDggDDggK..",
        "..KdDDDDDDDDDDDDDDDDDK..",
        "..KdDDDDDDDDDDDDDDDDK...",
        "..KdDDDDDDDDDDDDDDDK....",
        "..KdDDDDDDDDDDDDKKKKK...",
        ".KdDDDDDDDDDDDDDDDDDK...",
        "..KdDDDDDDDDDDDDDDDK....",
        "..KdDDDDDDDDDDDDDDDK....",
        "..KdDDDDDDDDDDDDDDDK....",
        "..KdDDDDDDDDDDDDDDDK....",
        "...KdpppppppppppppK.....",
        "....KdpppppppppppK......",
        ".....KdpppppppppppK.....",
        "......KdppKKKKKpppK.....",
        "......KdpK.....KdpK.....",
        "......KdpK.....KdpK.....",
        "......KdpK.....KdpK.....",
        "......KdpK.....KdpK.....",
        "......KKKK.....KKKK.....",
    },
    {
        ".........K..............",
        ".........W..............",
        "........KvK..K..........",
        "........KvWK.W..........",
        ".....K..KvWKKvK.........",
        ".....W..KvWKKvWK........",
        "....KvK.KvWKKvWK........",
        "....KvWKKvWKKvWKKK......",
        "....KvWKKvWKKKddddKK....",
        "....KvWK...KddDDDDddK...",
        "....KvWKKKKdDDDDDDDDdK..",
        ".....KKddddDDDDDDDDDDK..",
        "....KddDDDDDDDDYWDDYWK..",
        "...KdDDDDDDDDDDYYDDYYK..",
        "..KdDDDDDDDDDDDDDDDDDK..",
        "..KdDDDDDDDDDDDDDDDDK...",
        "..KdDDDDDDDDDDDDDDDK....",
        "..KdDDDDDDDDDDDDKKKKK...",
        ".KdDDDDDDDDDDDDDDDDDK...",
        "..KdDDDDDDDDDDDDDDDK....",
        "..KdDDDDDDDDDDDDDDDK....",
        "..KdDDDDDDDDDDDDDDDK....",
        "..KdDDDDDDDDDDDDDDDK....",
        "...KdpppppppppppppK.....",
        "....KdpppppppppppK......",
        ".....KdppppppppKppKK....",
        ".....KdppKKKKKK.KddK....",
        ".....KdpK.......KdpK....",
        ".....KdpK.......KdpK....",
        ".....KdpK.......KdpK....",
        ".....KdpK.......KdpK....",
        ".....KKKK.......KKKK....",
    },
    {
        ".........K..............",
        ".........W..............",
        "........KvK..K..........",
        "........KvWK.W..........",
        ".....K..KvWKKvK.........",
        ".....W..KvWKKvWK........",
        "....KvK.KvWKKvWK........",
        "....KvWKKvWKKvWKKK......",
        "....KvWKKvWKKKddddKK....",
        "....KvWK...KddDDDDddK...",
        "....KvWKKKKdDDDDDDDDdK..",
        ".....KKddddDDDDDDDDDDK..",
        "....KddDDDDDDDDYWDDYWK..",
        "...KdDDDDDDDDDDYYDDYYK..",
        "..KdDDDDDDDDDDDDDDDDDK..",
        "..KdDDDDDDDDDDDDDDDDK...",
        "..KdDDDDDDDDDDDDDDDK....",
        "..KdDDDDDDDDDDDDKKKKK...",
        ".KdDDDDDDDDDDDDDDDDDK...",
        "..KdDDDDDDDDDDDDDDDK....",
        "..KdDDDDDDDDDDDDDDDK....",
        "..KdDDDDDDDDDDDDDDDK....",
        "..KdDDDDDDDDDDDDDDDK....",
        "...KdpppppppppppppK.....",
        "....KdpppppppppppK......",
        ".....KKppppppppppK......",
        ".......KdppKKKpppK......",
        ".......KdpK...KdpK......",
        ".......KdpK...KdpK......",
        ".......KdpK...KdpK......",
        ".......KdpK...KdpK......",
        ".......KKKK...KKKK......",
    },
    {
        ".........K..............",
        ".........W..............",
        "........KvK..K..........",
        "........KvWK.W..........",
        ".....K..KvWKKvK.........",
        ".....W..KvWKKvWK........",
        "....KvK.KvWKKvWK........",
        "....KvWKKvWKKvWKKK......",
        "....KvWKKvWKKKddddKK....",
        "....KvWK...KddDDDDddK...",
        "....KvWKKKKdDDDDDDDDdK..",
        ".....KKddddDDDDRRDDRRK..",
        "....KddDDDDDDDDRYDDRYK..",
        "...KdDDDDDDDDDDRRDDRRK..",
        "..KdDDDDDDDDDDDDDDDDDK..",
        "..KdDDDDDDDDDDDDDDDDK...",
        "..KdDDDDDDDDDDKKKKKKK...",
        "..KdDDDDDDDDDDWrWrWrW...",
        ".KdDDDDDDDDDDDKKKKKKK...",
        "..KdDDDDDDDDDDDDDDDK....",
        "..KdDDDDDDDDDDDDDDDK....",
        "..KdDDDDDDDDDDDDDDDK....",
        "..KdDDDDDDDDDDDDDDDK....",
        "...KdpppppppppppppK.....",
        "....KdpppppppppppK......",
        ".....KdppppppppKppKK....",
        ".....KdppKKKKKK.KddK....",
        ".....KdpK.......KdpK....",
        ".....KdpK.......KdpK....",
        ".....KdpK.......KdpK....",
        ".....KdpK.......KdpK....",
        ".....KKKK.......KKKK....",
    },
}


-- cracked crystal rock (C in level 14): the cracks glow orange
defs['crystal-cracked'] = { recolor(defs['cracked'][1], { g = 'v', d = 'p', D = 'K', K = 'O' }) }

-- crystal shards on the floor (^) and hanging from ceilings (v): hurt like spikes
defs['crystal-spikes'] = { recolor(defs['spikes'][1], { W = 'C', g = 'W', d = 'g', D = 'p' }) }
defs['crystal-spikes-down'] = { flipRows(defs['crystal-spikes'][1]) }

-- crystal beetle (replaces the crawler in level 14): purple shell with
-- crystal spikes. 1-2 walking, 3 flipped over (dazed), 4 squashed,
-- 5 about to charge (red eye). Bottom on row 15 like the crawler.
local BEETLE_TOP = {
    "................",
    "................",
    "................",
    "................",
    ".....K....K.....",
    "....KvK..KvK....",
    "...KvWvKKvWvK...",
    "..KKpvpKKpvpKK..",
    ".KpppppppppppKK.",
    "KppvppppvpppKOYK",
    "KpppppppppppKYWK",
    "KDDDDDDDDDDDKKKK",
    ".KDDDDDDDDDDDDK.",
    "..KKKKKKKKKKKK..",
}
local function beetleFrame(feet)
    local f = {}
    for i = 1, #BEETLE_TOP do f[i] = BEETLE_TOP[i] end
    f[#f + 1] = feet
    f[#f + 1] = EMPTY_ROW
    return f
end
local BEETLE_WALK1 = beetleFrame("..KK.......KK...")
local BEETLE_WALK2 = beetleFrame("...KK.....KK....")
defs['beetle'] = {
    BEETLE_WALK1,
    BEETLE_WALK2,
    flipRows(BEETLE_WALK1),
    {
        EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW,
        EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW,
        "...K...K...K....",
        "..KvKKKvKKKvKK..",
        ".KppppppppppppK.",
        "KDDDDDDDDDDDDDDK",
        EMPTY_ROW,
    },
    recolor(BEETLE_WALK1, { O = 'R', Y = 'R' }),
}

-- spring / bounce pad (16 x 16): 1 ready, 2 launched (extended)
defs['spring'] = {
    {
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        ".KKKKKKKKKKKKKK.",
        ".KOOOOOOOOOOOOK.",
        ".KKKKKKKKKKKKKK.",
        "....KggggggK....",
        ".....KddddK.....",
        "....KggggggK....",
        "..KKKKKKKKKKKK..",
        "..KdddddddddDK..",
    },
    {
        "................",
        "................",
        "................",
        ".KKKKKKKKKKKKKK.",
        ".KOOOOOOOOOOOOK.",
        ".KKKKKKKKKKKKKK.",
        "......KddK......",
        "....KggggggK....",
        ".....KddddK.....",
        "....KggggggK....",
        ".....KddddK.....",
        "....KggggggK....",
        ".....KddddK.....",
        "....KggggggK....",
        "..KKKKKKKKKKKK..",
        "..KdddddddddDK..",
    },
}

-- checkpoint post (16 x 16): 1 not reached (grey), 2 reached (green)
local function checkpointFrame(knobA, knobB, cloth)
    local f = {
        "..KK............",
        ".K" .. knobA .. knobB .. "K...........",
        "..KK............",
        "..KgKKKKKKK.....",
        "..KgKPPPPPK.....",
        "..KgKPPPPK......",
        "..KgKPPPK.......",
        "..KgKPPK........",
        "..KgKKK.........",
        "..KgK...........",
        "..KgK...........",
        "..KgK...........",
        "..KgK...........",
        ".KKKKK..........",
        ".KdddK..........",
        ".KKKKK..........",
    }
    for i = 1, #f do f[i] = f[i]:gsub('P', cloth) end
    return f
end
defs['checkpoint'] = {
    checkpointFrame('g', 'd', 'd'),
    checkpointFrame('Y', 'W', 'L'),
}

-- key (12 x 6)
defs['key'] = {{
    ".KKKK.......",
    "KYWYOK......",
    "KYKKOKKKKKKK",
    "KYKKOYYYYYYK",
    "KOOOOKKKOKOK",
    ".KKKK...K.K.",
}}

---------------------------------------------------------------------------
-- HUD ICONS
---------------------------------------------------------------------------

defs['icon-air'] = {{
    "..KKK..",
    ".KCWCK.",
    "KCWCCCK",
    "KCCCCCK",
    "KCCCCSK",
    ".KCSSK.",
    "..KKK..",
}}

-- padlock for locked levels (9 x 11)
defs['icon-lock'] = {{
    "...KKK...",
    "..KdddK..",
    ".KdK.KdK.",
    ".KdK.KdK.",
    "KKKKKKKKK",
    "KYYYYYYOK",
    "KYYYKYYOK",
    "KYYYKYYOK",
    "KYYYYYOOK",
    "KOOOOOOOK",
    "KKKKKKKKK",
}}

---------------------------------------------------------------------------
-- BALL (generated): 3 sizes x 3 shapes x 8 spin angles
--   shapes: 1 round, 2 squash (landing), 3 stretch (fast fall / launch)
--   The ball has a white stripe and a gold air valve that turn as it rolls.
--   The shine stays put (light from the top-left), only the markings turn.
--   Frame number = shape + spin * 3   (spin 0..7), see Sprites.ballFrame.
--   So frames 1, 2, 3 are still round / squash / stretch with no spin.
---------------------------------------------------------------------------

Sprites.BALL_SPIN_FRAMES = 8

-- sprite diameter of each size = the ball's collision size (from constants)
Sprites.BALL_SIZES = {}
for i = 1, #BALL_SIZES do
    Sprites.BALL_SIZES[BALL_SIZES[i].name] = BALL_SIZES[i].diameter
end

function Sprites.ballFrame(shape, spin)
    return shape + (spin % Sprites.BALL_SPIN_FRAMES) * 3
end

-- rasterises a shaded pixel ellipse of w x h into a grid.
-- d: the round diameter (decides marking sizes). angle: spin in radians.
local function ballGrid(w, h, d, angle)
    local cx, cy = w / 2, h / 2
    local rx, ry = w / 2, h / 2

    local function inside(x, y)
        if x < 0 or y < 0 or x >= w or y >= h then return false end
        local nx = (x + 0.5 - cx) / rx
        local ny = (y + 0.5 - cy) / ry
        return nx * nx + ny * ny <= 1.0
    end

    -- markings, measured in "round ball" pixels so squash/stretch bends them too
    local r = d / 2
    local ca, sa = math.cos(angle), math.sin(angle)
    local stripeHalf = (d >= 20) and 1.3 or ((d >= 14) and 1.0 or 0)   -- Small: no stripe
    local valveDist = r * 0.58
    local valveR = (d >= 20) and 1.6 or ((d >= 14) and 1.3 or 0.75)
    -- valve sits a quarter turn from the stripe
    local vx, vy = -sa * valveDist, ca * valveDist

    local rows = {}
    for y = 0, h - 1 do
        local row = {}
        for x = 0, w - 1 do
            local ch = '.'
            if inside(x, y) then
                if not (inside(x - 1, y) and inside(x + 1, y)
                    and inside(x, y - 1) and inside(x, y + 1)) then
                    ch = 'K'                                -- outline
                else
                    local nx = (x + 0.5 - cx) / rx
                    local ny = (y + 0.5 - cy) / ry
                    local light = -(nx * 0.55 + ny * 0.85)  -- light from top-left
                    local px, py = nx * r, ny * r           -- position on the round ball
                    local dvx, dvy = px - vx, py - vy
                    if dvx * dvx + dvy * dvy <= valveR * valveR then
                        ch = (light > -0.1) and 'Y' or 'O'  -- gold air valve
                    elseif math.abs(-sa * px + ca * py) < stripeHalf then
                        ch = (light > -0.3) and 'W' or 'g'  -- stripe (greyer in shadow)
                    elseif light > 0.45 then ch = 'O'
                    elseif light < -0.3 then ch = 'r'
                    else ch = 'R' end
                end
            end
            row[x + 1] = ch
        end
        rows[y + 1] = row
    end

    -- shine: a small white highlight in the upper-left (drawn over the markings)
    local sx = math.floor(cx - rx * 0.45)
    local sy = math.floor(cy - ry * 0.5)
    local function shine(x, y)
        if rows[y + 1] and rows[y + 1][x + 1] and rows[y + 1][x + 1] ~= 'K'
            and rows[y + 1][x + 1] ~= '.' then
            rows[y + 1][x + 1] = 'W'
        end
    end
    shine(sx, sy)
    if w >= 12 then shine(sx + 1, sy); shine(sx, sy + 1) end
    if w >= 20 then shine(sx + 1, sy + 1); shine(sx + 2, sy); shine(sx, sy + 2) end

    for y = 1, h do rows[y] = table.concat(rows[y]) end
    return rows
end

for name, d in pairs(Sprites.BALL_SIZES) do
    local s = math.max(1, math.floor(d * 0.15 + 0.5))
    local frames = {}
    for spin = 0, Sprites.BALL_SPIN_FRAMES - 1 do
        local angle = spin / Sprites.BALL_SPIN_FRAMES * math.pi * 2
        frames[#frames + 1] = ballGrid(d, d, d, angle)            -- round
        frames[#frames + 1] = ballGrid(d + s, d - s, d, angle)    -- squash
        frames[#frames + 1] = ballGrid(d - s, d + s, d, angle)    -- stretch
    end
    defs['ball-' .. name] = frames
end

---------------------------------------------------------------------------
-- TOUCH BUTTONS (generated): round button + white icon.
--   frame 1 up, frame 2 pressed (lighter, icon turns yellow and drops 1px)
---------------------------------------------------------------------------

local ICONS = {
    left = {
        "...W...",
        "..WW...",
        ".WWWWWW",
        "WWWWWWW",
        ".WWWWWW",
        "..WW...",
        "...W...",
    },
    jump = {
        "...W...",
        "..WWW..",
        ".WWWWW.",
        "WWWWWWW",
        "..WWW..",
        "..WWW..",
        "..WWW..",
    },
    grow = {
        "..W..",
        "..W..",
        "WWWWW",
        "..W..",
        "..W..",
    },
    shrink = {
        ".....",
        ".....",
        "WWWWW",
        ".....",
        ".....",
    },
    pause = {
        "WW.WW",
        "WW.WW",
        "WW.WW",
        "WW.WW",
        "WW.WW",
    },
}
ICONS.right = {}
for i, row in ipairs(ICONS.left) do ICONS.right[i] = row:reverse() end   -- mirror

local function buttonGrid(d, icon, down)
    local c = d / 2
    local function inside(x, y)
        if x < 0 or y < 0 or x >= d or y >= d then return false end
        local nx, ny = (x + 0.5 - c) / c, (y + 0.5 - c) / c
        return nx * nx + ny * ny <= 1.0
    end
    local rows = {}
    for y = 0, d - 1 do
        local row = {}
        for x = 0, d - 1 do
            local ch = '.'
            if inside(x, y) then
                if not (inside(x - 1, y) and inside(x + 1, y)
                    and inside(x, y - 1) and inside(x, y + 1)) then
                    ch = 'K'
                elseif not inside(x, y - 2) then
                    ch = down and 'g' or 'd'          -- rim highlight at the top
                else
                    ch = down and 'd' or 'D'
                end
            end
            row[x + 1] = ch
        end
        rows[y + 1] = row
    end
    local ih, iw = #icon, #icon[1]
    local ox = math.floor((d - iw) / 2)
    local oy = math.floor((d - ih) / 2) + (down and 1 or 0)
    for y = 1, ih do
        for x = 1, iw do
            if icon[y]:sub(x, x) == 'W' then
                rows[oy + y][ox + x] = down and 'Y' or 'W'
            end
        end
    end
    for y = 1, d do rows[y] = table.concat(rows[y]) end
    return rows
end

local BUTTON_SIZES = { left = 20, right = 20, jump = 20, grow = 13, shrink = 13, pause = 11 }
for name, d in pairs(BUTTON_SIZES) do
    defs['btn-' .. name] = { buttonGrid(d, ICONS[name], false), buttonGrid(d, ICONS[name], true) }
end
