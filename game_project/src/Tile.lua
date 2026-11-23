--[[
    Inflate - Tile
    One cell of the level grid. Its kind decides how it looks and behaves.
]]

Tile = Class{}

-- kind -> properties
TILE_DEFS = {
    ['grass']   = { sprite = 'ground-top', solid = true },   -- ground with nothing above
    ['ground']  = { sprite = 'ground',     solid = true },
    ['stone']   = { sprite = 'stone',      solid = true },
    ['cracked'] = { sprite = 'cracked',    solid = true, breakable = true },
    ['spikes']  = { sprite = 'spikes',     solid = false, hazard = true },
    -- cave theme versions of ground
    ['rock-top'] = { sprite = 'rock-top',  solid = true },
    ['rock']     = { sprite = 'rock',      solid = true },
    -- locked door: solid until the ball touches it carrying a key
    ['door']    = { sprite = 'door',       solid = true, door = true },
    -- factory theme versions of ground / stone
    ['metal-top'] = { sprite = 'metal-top', solid = true },
    ['metal']     = { sprite = 'metal',     solid = true },
    ['steel']     = { sprite = 'steel',     solid = true },
    -- ruins theme (sunken gardens) versions of ground / stone
    ['ruin-top'] = { sprite = 'ruin-top', solid = true },
    ['ruin']     = { sprite = 'ruin',     solid = true },
    ['carved']   = { sprite = 'carved',   solid = true },
    -- grove theme (lantern grove) versions of ground / stone
    ['root-top'] = { sprite = 'root-top', solid = true },
    ['bark']     = { sprite = 'bark',     solid = true },
    ['planks']   = { sprite = 'planks',   solid = true },
    -- ice theme (frostpeak) versions of ground / stone, and hanging icicles
    -- (hazardBox: the part that hurts, x / y / w / h inside the tile)
    ['snow-top'] = { sprite = 'snow-top', solid = true },
    ['ice']      = { sprite = 'ice',      solid = true },
    ['icebrick'] = { sprite = 'icebrick', solid = true },
    ['icicle']   = { sprite = 'icicle',   solid = false, hazard = true, hazardBox = {1, 0, 14, 15} },
    -- space theme (starfall) versions of ground / stone, and ceiling spikes.
    -- astro-bottom: the underside of rock (the ball rolls there upside down)
    ['astro-top']    = { sprite = 'astro-top',    solid = true },
    ['astro']        = { sprite = 'astro',        solid = true },
    ['astro-bottom'] = { sprite = 'astro-bottom', solid = true },
    ['brass']        = { sprite = 'brass',        solid = true },
    ['spikes-down']  = { sprite = 'spikes-down',  solid = false, hazard = true, hazardBox = {2, 0, 12, 7} },
    -- crystal cave (level 14) versions of ground / stone
    ['crystal-top']    = { sprite = 'crystal-top',    solid = true },
    ['crystal-rock']   = { sprite = 'crystal-rock',   solid = true },
    ['crystal-bottom'] = { sprite = 'crystal-bottom', solid = true },
    ['amethyst']       = { sprite = 'amethyst',       solid = true },
    -- jungle (level 15) versions of ground / stone
    ['jungle-top']    = { sprite = 'jungle-top',    solid = true },
    ['jungle-soil']   = { sprite = 'jungle-soil',   solid = true },
    ['jungle-bottom'] = { sprite = 'jungle-bottom', solid = true },
    ['mossy-stone']   = { sprite = 'mossy-stone',   solid = true },
    -- gate: solid while closed, opened by pressure plates (see GameLevel gates)
    ['gate']     = { sprite = 'gate-1',   solid = true, gate = true },
    -- fans (solid blocks that blow air, see GameLevel fans)
    ['vent']     = { sprite = 'vent',     solid = true, fan = 'up' },
    ['blower-l'] = { sprite = 'blower-l', solid = true, fan = 'left' },
    ['blower-r'] = { sprite = 'blower-r', solid = true, fan = 'right' },
}

function Tile:init(col, row, kind)
    local def = assert(TILE_DEFS[kind], 'Unknown tile kind: ' .. tostring(kind))
    self.col = col
    self.row = row
    self.x = (col - 1) * TILE_SIZE
    self.y = (row - 1) * TILE_SIZE
    self.kind = kind
    self.sprite = def.sprite
    self.solid = def.solid
    self.hazard = def.hazard or false
    self.hazardBox = def.hazardBox     -- nil = spikes (bottom part of the tile)
    self.breakable = def.breakable or false
    self.door = def.door or false
    self.fan = def.fan             -- 'up' / 'left' / 'right' or nil
    self.fanGroup = 0              -- 0 always on, 1 / 2 take turns (set by LevelMaker)
    self.gate = def.gate or false
    self.gateGroup = 0             -- which plates open this gate (set by LevelMaker)
    self.frame = 1                 -- animated tiles (fans) change this
end

function Tile:render()
    SpriteBuilder.draw(self.sprite, self.frame, self.x, self.y)
end
