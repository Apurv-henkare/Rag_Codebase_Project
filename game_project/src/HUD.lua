--[[
    Inflate - HUD
    Air bar (top-left) and gem counter (top-right), drawn in screen space.
    The air bar shows how much air is left: cyan when healthy, orange when
    getting low, red and blinking when nearly empty.
]]

HUD = {}

local lg = love.graphics
local mfloor, mceil = math.floor, math.ceil

local BAR_X, BAR_Y = 14, 6
local BAR_W, BAR_H = 60, 5

function HUD.render(ball, level, time)
    -- air icon + bar
    SpriteBuilder.draw('icon-air', 1, 4, 5)

    local ratio = clamp(ball.air / AIR_MAX, 0, 1)
    local fillColor = 'C'
    if ratio <= LOW_AIR then fillColor = 'R'
    elseif ratio <= 0.5 then fillColor = 'O' end
    local blinkOff = ratio <= LOW_AIR and ratio > 0 and mfloor(time * 6) % 2 == 0

    -- frame: black border, dark inside
    Palette.set('K')
    lg.rectangle('fill', BAR_X - 1, BAR_Y - 1, BAR_W + 2, BAR_H + 2)
    Palette.set('D')
    lg.rectangle('fill', BAR_X, BAR_Y, BAR_W, BAR_H)

    local fillW = mfloor(BAR_W * ratio + 0.5)
    if fillW > 0 and not blinkOff then
        Palette.set(fillColor)
        lg.rectangle('fill', BAR_X, BAR_Y, fillW, BAR_H)
        -- 1px highlight along the top of the fill
        Palette.set('W')
        lg.rectangle('fill', BAR_X, BAR_Y, fillW, 1)
    end

    PixelFont.print(tostring(mceil(clamp(ball.air, 0, AIR_MAX))), BAR_X + BAR_W + 5, 5,
        {color = 'W', outline = 'K'})

    -- gems: icon + count, right-aligned
    local text = level.gemsCollected .. '/' .. level.totalGems
    local textW = PixelFont.width(text)
    local x = VIRTUAL_WIDTH - 5 - textW
    PixelFont.print(text, x, 5, {color = 'Y', outline = 'K'})
    SpriteBuilder.draw('gem', 1, x - 11, 4)

    -- key(s) being carried, under the air bar
    if level.keys > 0 then
        SpriteBuilder.draw('key', 1, 4, 15)
        if level.keys > 1 then
            PixelFont.print('x' .. level.keys, 18, 15, {color = 'Y', outline = 'K'})
        end
    end

    lg.setColor(1, 1, 1, 1)
end
