--[[
    Inflate - LevelMaker
    Turns a text level into a GameLevel.

    Level legend:
        .  empty            #  ground (grass shows automatically on top)
        =  stone block      C  cracked block (Big ball breaks it)
        ^  spikes           P  air pump
        *  gem              E  spiky crawler (walks)
        B  buzzer (flies)   S  start
        G  goal flag        H  checkpoint
        J  spring           K  key
        D  locked door (needs a key; touching doors are opened together)
        F  vent: fan in the floor, blows up (always on)
        U  vent, on/off      V  vent, on/off (on while the U vents are off)
        <  blower: fan in a wall, blows left      >  blows right
        a-f  pressure plate of group 1-6 (only Big presses it)
        1-6  gate of group 1-6: opens while all plates of its group are active.
             The level file's  timers = { [group] = seconds }  makes that
             group's plates timer plates; the others are hold plates.
        L  hanging lantern (decoration with a warm glow)
        v  icicles hanging from the ceiling (hurt like spikes); spikes in 'space'
        u  gravity orb: flips gravity UP     n  gravity orb: back DOWN
        x y z  glowing crystal cluster (purple / orange / silver), decoration
        M  the Shade: can't be hurt, wakes when the ball comes close and
           chases it (can't jump, never walks up to a checkpoint)
        W  waterfall: falls from this cell down to the ground or a pool and
           pushes the ball down (Small a lot, Big hardly). Put several side
           by side for a wide fall.
        N  snake (hides in the grass, lunges out)   Y  monkey (throws coconuts)
        T  snapper plant (can't be hurt, bites)     I  piranha (in water, leaps;
                                                       can't be hurt)
        Moving platforms are not in the grid: the level file lists them in
        platforms = { { col, row, len, toCol, toRow, speed, wake, group }, ... }
        (col, row) = left cell at the start, (toCol, toRow) = left cell at
        the end. wake = waits until the ball lands on it. group = carries a
        rider to the end only while that plate group is active, else goes back.
        ~  water             o  bubble stream (on the floor, under water)
           Objects / enemies / spikes written inside water are under water too
           (a cell is water if the cell above is water, or it sits next to
           water in the same row).

    A level file can set theme:
        'sky'      default: grass, dirt, stone, blue sky
        'cave'     ground is rock, cave background
        'factory'  metal floors with hazard stripes, teal steel blocks (=),
                   factory background, robot enemies
        'ruins'    sand on old stone, carved blocks (=), sunken ruins
                   background, crab + jellyfish enemies
        'grove'    mossy roots and bark, wooden planks (=), dusk forest with
                   lanterns and fireflies, hedgehog + moth enemies
        'ice'      snow on ice, ice bricks (=), cracked ice, night sky with
                   an aurora, stars and snow, penguin + owl enemies
        'space'    floating rock with crystal veins, brass blocks (=), space
                   with a ringed planet and nebula, slug + spark star enemies
        'crystal'  purple rock with crystal crusts, amethyst blocks (=),
                   crystal shards (^ v), a giant crystal
                   cavern; crystal beetles that charge and cave bats that
                   swoop (smarter crawler / buzzer)
        'jungle'   grassy soil, mossy temple stone (=), orange thorns (^ v),
                   sunny jungle with cliffs and waterfalls; caves (empty
                   cells with ground somewhere above) get a dark rock wall
                   behind them. E = frog (hops), B = flying beetle (drifts,
                   dives), M = the Stone Guardian; x / y / z = glowing
                   mushrooms / a flower / a fern

    Rows shorter than the longest row are padded with empty space.
]]

LevelMaker = {}

-- objects: sprite, size, offset inside the cell, animation (optional), hitbox (optional)
local OBJECT_DEFS = {
    ['P'] = { type = 'pump', sprite = 'pump', w = 16, h = 16, ox = 0, oy = 0,
              hitbox = {2, 1, 12, 15} },
    ['*'] = { type = 'gem', sprite = 'gem', w = 8, h = 8, ox = 4, oy = 4,
              frames = {1, 1, 1, 1, 2}, interval = 0.2, randomize = true,
              hitbox = {0, 0, 8, 7} },
    -- flag is 2 cells tall: its bottom sits on the bottom of the G cell
    ['G'] = { type = 'goal', sprite = 'flag', w = 16, h = 32, ox = 0, oy = -16,
              frames = {1, 2}, interval = 0.4,
              hitbox = {0, 2, 13, 30} },
    ['H'] = { type = 'checkpoint', sprite = 'checkpoint', w = 16, h = 16, ox = 0, oy = 0,
              hitbox = {0, 0, 10, 16} },
    ['J'] = { type = 'spring', sprite = 'spring', w = 16, h = 16, ox = 0, oy = 0,
              hitbox = {2, 7, 12, 9} },
    ['K'] = { type = 'key', sprite = 'key', w = 12, h = 6, ox = 2, oy = 6 },
    ['o'] = { type = 'bubbles', sprite = 'bubble-vent', w = 16, h = 16, ox = 0, oy = 0,
              hitbox = {0, 0, 0, 0} },
    ['L'] = { type = 'lantern', sprite = 'lantern', w = 16, h = 16, ox = 0, oy = 0,
              hitbox = {0, 0, 0, 0} },
    -- gravity orbs: dir -1 = gravity up, 1 = back down
    ['u'] = { type = 'orb', sprite = 'orb-up', dir = -1, w = 16, h = 16, ox = 0, oy = 0,
              frames = {1, 2}, interval = 0.3, randomize = true, hitbox = {2, 2, 12, 12} },
    ['n'] = { type = 'orb', sprite = 'orb-down', dir = 1, w = 16, h = 16, ox = 0, oy = 0,
              frames = {1, 2}, interval = 0.3, randomize = true, hitbox = {2, 2, 12, 12} },
    -- glowing crystal clusters (decoration)
    ['x'] = { type = 'crystal', sprite = 'cluster-purple', glow = 'v', w = 16, h = 16, ox = 0, oy = 0,
              hitbox = {0, 0, 0, 0} },
    ['y'] = { type = 'crystal', sprite = 'cluster-orange', glow = 'O', w = 16, h = 16, ox = 0, oy = 0,
              hitbox = {0, 0, 0, 0} },
    ['z'] = { type = 'crystal', sprite = 'cluster-silver', glow = 'C', w = 16, h = 16, ox = 0, oy = 0,
              hitbox = {0, 0, 0, 0} },
}
-- the same decorations in the jungle: sprite and glow (nil = no glow)
local JUNGLE_DECOR = {
    ['x'] = { sprite = 'glow-mushroom', glow = 'C' },
    ['y'] = { sprite = 'jungle-flower' },
    ['z'] = { sprite = 'fern' },
}
-- pressure plates a-f (groups 1-6): a thin plate lying on the floor
for i, ch in ipairs({'a', 'b', 'c', 'd', 'e', 'f'}) do
    OBJECT_DEFS[ch] = { type = 'plate', sprite = 'plate-' .. i, group = i,
                        w = 16, h = 16, ox = 0, oy = 0, hitbox = {1, 12, 14, 4} }
end

-- characters that are solid tiles (never water)
local SOLID_CHARS = { ['#'] = true, ['='] = true, ['C'] = true, ['D'] = true,
                      ['F'] = true, ['U'] = true, ['V'] = true, ['<'] = true, ['>'] = true,
                      ['1'] = true, ['2'] = true, ['3'] = true, ['4'] = true,
                      ['5'] = true, ['6'] = true }

-- water[row][col]: '~' cells, plus anything written inside water (see legend).
-- behind[row][col]: cracked blocks / doors in water: they turn into water
-- when they are smashed / opened (so no dry hole is left behind).
local function findWater(rows, numRows, numCols, charAt)
    local water, behind = {}, {}
    for r = 1, numRows do
        local w, b = {}, {}
        water[r], behind[r] = w, b
        local above, aboveB = water[r - 1], behind[r - 1]
        for c = 1, numCols do
            local ch = charAt(c, r)
            if ch == '~' then
                w[c] = true
            elseif ch ~= '.' and not SOLID_CHARS[ch] and above and above[c] then
                w[c] = true
            end
        end
        -- objects next to water in the same row (both directions)
        for _, dir in ipairs({1, -1}) do
            local c1, c2 = 1, numCols
            if dir < 0 then c1, c2 = numCols, 1 end
            for c = c1, c2, dir do
                local ch = charAt(c, r)
                if not w[c] and ch ~= '.' and not SOLID_CHARS[ch] and w[c - dir] then
                    w[c] = true
                end
            end
        end
        for c = 1, numCols do
            local ch = charAt(c, r)
            if (ch == 'C' or ch == 'D') and ((above and (above[c] or aboveB[c]))
                or w[c - 1] or w[c + 1] or b[c - 1]) then
                b[c] = true
            end
        end
    end
    return water, behind
end

local ENEMY_CHARS = {
    ['E'] = 'crawler',
    ['B'] = 'buzzer',
    ['M'] = 'shade',
    ['N'] = 'snake',
    ['Y'] = 'monkey',
    ['T'] = 'plant',
    ['I'] = 'piranha',
}
-- in the jungle the crawler is a frog and the buzzer a flying beetle
local JUNGLE_ENEMIES = { crawler = 'frog', buzzer = 'bug' }

local TILE_CHARS = {
    ['#'] = 'ground',
    ['='] = 'stone',
    ['C'] = 'cracked',
    ['^'] = 'spikes',
    ['D'] = 'door',
    ['F'] = 'vent',
    ['U'] = 'vent',
    ['V'] = 'vent',
    ['<'] = 'blower-l',
    ['>'] = 'blower-r',
    ['v'] = 'icicle',
    ['1'] = 'gate', ['2'] = 'gate', ['3'] = 'gate',
    ['4'] = 'gate', ['5'] = 'gate', ['6'] = 'gate',
}

-- vents that take turns (see FAN_ON_TIME): U = group 1, V = group 2
local FAN_GROUPS = { ['U'] = 1, ['V'] = 2 }

-- rows: list of strings. name: level title. theme: 'sky' (default), 'cave',
-- 'factory', 'ruins', 'grove', 'ice', 'space', 'crystal' or 'jungle'. timers: { [group] = seconds } (optional)
-- platforms: list of moving platforms (optional, see the legend above)
function LevelMaker.build(rows, name, theme, timers, platforms)
    theme = theme or 'sky'
    timers = timers or {}
    local numRows = #rows
    local numCols = 0
    for r = 1, numRows do
        if #rows[r] > numCols then numCols = #rows[r] end
    end

    local function charAt(col, row)
        local line = rows[row]
        if not line or col > #line then return '.' end
        return line:sub(col, col)
    end

    local tileMap = TileMap(numCols, numRows)
    local water, waterBehind = findWater(rows, numRows, numCols, charAt)
    local objects = {}
    local enemies = {}
    local waterfalls = {}
    local spawnX, spawnY

    for r = 1, numRows do
        for c = 1, numCols do
            local ch = charAt(c, r)
            local cellX = (c - 1) * TILE_SIZE
            local cellY = (r - 1) * TILE_SIZE

            if TILE_CHARS[ch] then
                local kind = TILE_CHARS[ch]
                -- ground with no ground above it gets grass
                if kind == 'ground' then
                    local top = charAt(c, r - 1) ~= '#'
                    if theme == 'cave' then
                        kind = top and 'rock-top' or 'rock'
                    elseif theme == 'factory' then
                        kind = top and 'metal-top' or 'metal'
                    elseif theme == 'ruins' then
                        kind = top and 'ruin-top' or 'ruin'
                    elseif theme == 'grove' then
                        kind = top and 'root-top' or 'bark'
                    elseif theme == 'ice' then
                        kind = top and 'snow-top' or 'ice'
                    elseif theme == 'space' then
                        local bottom = charAt(c, r + 1) ~= '#'
                        kind = top and 'astro-top' or (bottom and 'astro-bottom' or 'astro')
                    elseif theme == 'crystal' then
                        local bottom = charAt(c, r + 1) ~= '#'
                        kind = top and 'crystal-top' or (bottom and 'crystal-bottom' or 'crystal-rock')
                    elseif theme == 'jungle' then
                        local bottom = charAt(c, r + 1) ~= '#'
                        kind = top and 'jungle-top' or (bottom and 'jungle-bottom' or 'jungle-soil')
                    elseif top then
                        kind = 'grass'
                    end
                elseif kind == 'stone' and theme == 'factory' then
                    kind = 'steel'
                elseif kind == 'stone' and theme == 'ruins' then
                    kind = 'carved'
                elseif kind == 'stone' and theme == 'grove' then
                    kind = 'planks'
                elseif kind == 'stone' and theme == 'ice' then
                    kind = 'icebrick'
                elseif kind == 'stone' and theme == 'space' then
                    kind = 'brass'
                elseif kind == 'stone' and theme == 'crystal' then
                    kind = 'amethyst'
                elseif kind == 'stone' and theme == 'jungle' then
                    kind = 'mossy-stone'
                elseif kind == 'icicle' and (theme == 'space' or theme == 'crystal' or theme == 'jungle') then
                    kind = 'spikes-down'
                end
                local tile = Tile(c, r, kind)
                tile.waterBehind = waterBehind[r][c] or false
                if kind == 'gate' then
                    tile.gateGroup = tonumber(ch)
                    tile.sprite = 'gate-' .. ch
                elseif kind == 'cracked' and theme == 'ice' then
                    tile.sprite = 'ice-cracked'
                elseif kind == 'cracked' and theme == 'space' then
                    tile.sprite = 'astro-cracked'
                elseif kind == 'cracked' and theme == 'crystal' then
                    tile.sprite = 'crystal-cracked'
                elseif kind == 'spikes' and theme == 'crystal' then
                    tile.sprite = 'crystal-spikes'
                elseif kind == 'spikes-down' and theme == 'crystal' then
                    tile.sprite = 'crystal-spikes-down'
                elseif kind == 'cracked' and theme == 'jungle' then
                    tile.sprite = 'jungle-cracked'
                elseif kind == 'spikes' and theme == 'jungle' then
                    tile.sprite = 'thorns'
                elseif kind == 'spikes-down' and theme == 'jungle' then
                    tile.sprite = 'thorns-down'
                end
                tile.fanGroup = FAN_GROUPS[ch] or 0
                tileMap:setTile(c, r, tile)

            elseif OBJECT_DEFS[ch] then
                local d = OBJECT_DEFS[ch]
                local anim = nil
                if d.frames then
                    anim = Animation{ frames = d.frames, interval = d.interval }
                    if d.randomize then anim:randomize() end
                end
                -- timer plates look different (a clock dot on each side)
                local duration = d.group and timers[d.group]
                local sprite = duration and ('tplate-' .. d.group) or d.sprite
                local glow = d.glow
                local decor = (theme == 'jungle') and JUNGLE_DECOR[ch]
                if decor then sprite, glow = decor.sprite, decor.glow end
                objects[#objects + 1] = GameObject{
                    type = d.type,
                    x = cellX + d.ox,
                    y = cellY + d.oy,
                    width = d.w,
                    height = d.h,
                    sprite = sprite,
                    animation = anim,
                    hitbox = d.hitbox,
                    group = d.group,
                    duration = duration,
                    dir = d.dir,
                    glow = glow,
                }

            elseif ENEMY_CHARS[ch] then
                local kind = ENEMY_CHARS[ch]
                if theme == 'jungle' then kind = JUNGLE_ENEMIES[kind] or kind end
                enemies[#enemies + 1] = Enemy(kind, tileMap, cellX, cellY, theme)

            elseif ch == 'W' then
                waterfalls[#waterfalls + 1] = { col = c, row = r }

            elseif ch == 'S' then
                spawnX = cellX + TILE_SIZE / 2
                spawnY = cellY + TILE_SIZE

            elseif ch ~= '.' and ch ~= '~' then
                error(('Level "%s": unknown character "%s" at row %d, column %d')
                    :format(name or '?', ch, r, c))
            end

            if water[r][c] then tileMap:setWater(c, r) end
        end
    end

    assert(spawnX, 'Level "' .. tostring(name) .. '" has no start (S)')

    -- jungle caves: every open cell with ground somewhere above it shows a
    -- dark rock wall behind it (so caves look like caves, not open sky)
    if theme == 'jungle' then
        for c = 1, numCols do
            local roof = false
            for r = 1, numRows do
                local ch = charAt(c, r)
                if ch == '#' or ch == 'C' then
                    -- a smashed block inside a cave leaves wall behind it
                    if roof and ch == 'C' then tileMap:setBack(c, r, 1) end
                    roof = true
                elseif roof and not SOLID_CHARS[ch] then
                    -- a root hangs down the wall here and there
                    tileMap:setBack(c, r, ((c * 7 + r * 3) % 11 == 0) and 2 or 1)
                end
            end
        end
    end

    -- shades never walk up to a checkpoint (bottom-centre of each)
    local safeSpots = {}
    for i = 1, #objects do
        local o = objects[i]
        if o.type == 'checkpoint' then
            safeSpots[#safeSpots + 1] = { x = o.x + 8, y = o.y + TILE_SIZE }
        end
    end
    for i = 1, #enemies do
        if enemies[i].kind == 'shade' then enemies[i].safeSpots = safeSpots end
    end

    return GameLevel{
        name = name,
        tileMap = tileMap,
        objects = objects,
        enemies = enemies,
        spawnX = spawnX,
        spawnY = spawnY,
        theme = theme,
        platforms = platforms,
        waterfalls = waterfalls,
    }
end

-- loads src/levels/level<n>.lua (returns { name = ..., rows = {...} })
function LevelMaker.load(n)
    local data = require('src/levels/level' .. n)
    return LevelMaker.build(data.rows, data.name, data.theme, data.timers, data.platforms)
end

-- name and gem count of a level without building it (for the level select)
function LevelMaker.info(n)
    local data = require('src/levels/level' .. n)
    local gems = 0
    for r = 1, #data.rows do
        local _, count = data.rows[r]:gsub('%*', '')
        gems = gems + count
    end
    return { name = data.name, gems = gems }
end
