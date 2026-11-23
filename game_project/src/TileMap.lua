--[[
    Inflate - TileMap
    The level grid. tiles[row][col] is a Tile or nil (empty).
    Only tiles inside the camera view are drawn.
]]

TileMap = Class{}

local mfloor, mmax, mmin = math.floor, math.max, math.min

function TileMap:init(cols, rows)
    self.cols = cols
    self.rows = rows
    self.width = cols * TILE_SIZE     -- in pixels
    self.height = rows * TILE_SIZE
    self.tiles = {}
    for r = 1, rows do self.tiles[r] = {} end
    -- water is a separate layer: water[row][col] = true (cells stay empty / hold objects)
    self.water = {}
    for r = 1, rows do self.water[r] = {} end
    self.hasWater = false
    -- cave wall drawn behind open cells (jungle caves): back[row][col] = frame
    self.back = {}
    for r = 1, rows do self.back[r] = {} end
end

function TileMap:setBack(col, row, frame)
    self.back[row][col] = frame
end

function TileMap:setWater(col, row)
    self.water[row][col] = true
    self.hasWater = true
end

function TileMap:isWater(col, row)
    local r = self.water[row]
    return r ~= nil and r[col] == true
end

-- is the pixel position under water?
function TileMap:isWaterAt(px, py)
    return self:isWater(mfloor(px / TILE_SIZE) + 1, mfloor(py / TILE_SIZE) + 1)
end

-- y of the water surface above a pixel position that is under water
function TileMap:waterSurface(px, py)
    local col, row = mfloor(px / TILE_SIZE) + 1, mfloor(py / TILE_SIZE) + 1
    while row > 1 and self:isWater(col, row - 1) do row = row - 1 end
    return (row - 1) * TILE_SIZE
end

function TileMap:setTile(col, row, tile)
    self.tiles[row][col] = tile
end

-- tile at grid position, or nil (also nil outside the map)
function TileMap:getTile(col, row)
    local r = self.tiles[row]
    return r and r[col] or nil
end

-- tile under a pixel position, or nil
function TileMap:pointToTile(px, py)
    return self:getTile(mfloor(px / TILE_SIZE) + 1, mfloor(py / TILE_SIZE) + 1)
end

function TileMap:isSolidAt(px, py)
    local t = self:pointToTile(px, py)
    return t ~= nil and t.solid
end

---------------------------------------------------------------------------
-- COLLISION (boxes in pixels; moves must be smaller than one tile per call)
---------------------------------------------------------------------------
local EPS = 0.001

local function solidTile(self, col, row)
    local t = self:getTile(col, row)
    if t and t.solid then return t end
    return nil
end

-- true if any solid tile overlaps the box
function TileMap:boxCollides(x, y, w, h)
    local c1, c2 = mfloor(x / TILE_SIZE) + 1, mfloor((x + w - EPS) / TILE_SIZE) + 1
    local r1, r2 = mfloor(y / TILE_SIZE) + 1, mfloor((y + h - EPS) / TILE_SIZE) + 1
    for r = r1, r2 do
        for c = c1, c2 do
            if solidTile(self, c, r) then return true end
        end
    end
    return false
end

-- moves a box horizontally by dx; stops at solid tiles.
-- returns new x and the tile hit (or nil)
function TileMap:sweepX(x, y, w, h, dx)
    if dx == 0 then return x, nil end
    local newX = x + dx
    local r1, r2 = mfloor(y / TILE_SIZE) + 1, mfloor((y + h - EPS) / TILE_SIZE) + 1
    local col = dx > 0 and mfloor((newX + w - EPS) / TILE_SIZE) + 1
                        or mfloor(newX / TILE_SIZE) + 1
    for r = r1, r2 do
        local t = solidTile(self, col, r)
        if t then
            if dx > 0 then return (col - 1) * TILE_SIZE - w, t end
            return col * TILE_SIZE, t
        end
    end
    return newX, nil
end

-- moves a box vertically by dy; stops at solid tiles.
-- returns new y and the tile hit (or nil)
function TileMap:sweepY(x, y, w, h, dy)
    if dy == 0 then return y, nil end
    local newY = y + dy
    local c1, c2 = mfloor(x / TILE_SIZE) + 1, mfloor((x + w - EPS) / TILE_SIZE) + 1
    local row = dy > 0 and mfloor((newY + h - EPS) / TILE_SIZE) + 1
                        or mfloor(newY / TILE_SIZE) + 1
    for c = c1, c2 do
        local t = solidTile(self, c, row)
        if t then
            if dy > 0 then return (row - 1) * TILE_SIZE - h, t end
            return row * TILE_SIZE, t
        end
    end
    return newY, nil
end

-- a smashed block / opened door that was in water leaves water behind
function TileMap:removeTile(col, row)
    local r = self.tiles[row]
    if not r then return end
    local t = r[col]
    r[col] = nil
    if t and t.waterBehind then self:setWater(col, row) end
end

-- draws only the tiles visible from camera position (camX, camY)
function TileMap:render(camX, camY)
    local firstCol = mmax(1, mfloor(camX / TILE_SIZE) + 1)
    local lastCol  = mmin(self.cols, mfloor((camX + VIRTUAL_WIDTH) / TILE_SIZE) + 1)
    local firstRow = mmax(1, mfloor(camY / TILE_SIZE) + 1)
    local lastRow  = mmin(self.rows, mfloor((camY + VIRTUAL_HEIGHT) / TILE_SIZE) + 1)

    local draw = SpriteBuilder.draw
    for r = firstRow, lastRow do
        local row, back = self.tiles[r], self.back[r]
        local y = (r - 1) * TILE_SIZE
        for c = firstCol, lastCol do
            local b = back[c]
            if b then draw('jungle-cave', b, (c - 1) * TILE_SIZE, y) end
            local t = row[c]
            if t then t:render() end
        end
    end
end
