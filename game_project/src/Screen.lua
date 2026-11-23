--[[
    Inflate - Screen
    Draws the game onto any window / phone / tablet screen, scaled by WHOLE
    numbers only so every game pixel stays a crisp square.

    The scale is the biggest whole number that fits 320 x 180. The leftover
    space is NOT black bars: the view (VIRTUAL_WIDTH x VIRTUAL_HEIGHT) is made
    bigger so the game fills the screen and you see a bit more of the level.

      landscape (or square): game fills the screen, touch buttons in the corners
      portrait (phone held upright): game at the top (full width), touch
                             buttons in the panel underneath (handheld style)

    Everything here works in real screen pixels (also on high-DPI screens).
    Replaces push.lua so the layout can change with the screen shape.
]]

Screen = {}

local lg = love.graphics
local mfloor, mmax, mmin = math.floor, math.max, math.min

local mceil = math.ceil
local canvas

function Screen.init()
    Screen.resize()
end

-- call whenever the window size changes (love.resize) or the phone rotates
function Screen.resize()
    local dpi = lg.getDPIScale()
    local pw, ph = lg.getPixelDimensions()
    Screen.dpi = dpi
    Screen.width, Screen.height = pw, ph

    local portrait = ph > pw * 1.1
    Screen.portrait = portrait

    local s, vw, vh, gx, gy, ctrl
    if portrait then
        -- as wide as fits, but leave at least ~45% of the height for the buttons
        s = mmax(1, mmin(mfloor(pw / BASE_WIDTH), mfloor(ph * 0.55 / BASE_HEIGHT)))
        vw, vh = mceil(pw / s), BASE_HEIGHT        -- full width, normal height
        gx = mfloor((pw - vw * s) / 2)
        gy = mfloor(ph * 0.06)                       -- a little room for notches
        local top = gy + vh * s
        ctrl = { x = 0, y = top, w = pw, h = ph - top }
    else
        s = mmax(1, mfloor(mmin(pw / BASE_WIDTH, ph / BASE_HEIGHT)))
        vw, vh = mceil(pw / s), mceil(ph / s)      -- fill the whole screen
        gx = mfloor((pw - vw * s) / 2)               -- 0 or a pixel or two off-screen
        gy = mfloor((ph - vh * s) / 2)
        ctrl = { x = 0, y = 0, w = pw, h = ph }
    end

    -- the view the game draws into
    VIRTUAL_WIDTH, VIRTUAL_HEIGHT = vw, vh
    if not canvas or canvas:getWidth() ~= vw or canvas:getHeight() ~= vh then
        canvas = lg.newCanvas(vw, vh)
        canvas:setFilter('nearest', 'nearest')
    end
    -- where the 320 x 180 menu layout sits inside the view (centred)
    Screen.uiX = mfloor((vw - BASE_WIDTH) / 2)
    Screen.uiY = mfloor((vh - BASE_HEIGHT) / 2)

    Screen.scale, Screen.gameX, Screen.gameY = s, gx, gy
    Screen.controlArea = ctrl
    TouchControls.reset()   -- fingers from before the resize are stale
    TouchControls.layout(ctrl, portrait)
end

-- LÖVE gives mouse / touch positions in DPI-scaled units; convert to pixels
function Screen.toPixels(x, y)
    return x * Screen.dpi, y * Screen.dpi
end

-- screen pixels -> view pixels (may be outside the view)
function Screen.toGame(px, py)
    return (px - Screen.gameX) / Screen.scale, (py - Screen.gameY) / Screen.scale
end

function Screen.isInsideGame(gx, gy)
    return gx >= 0 and gy >= 0 and gx < VIRTUAL_WIDTH and gy < VIRTUAL_HEIGHT
end

-- menus: draw a 320 x 180 layout centred in the view
function Screen.beginUI()
    lg.push()
    lg.translate(Screen.uiX, Screen.uiY)
    PixelFont.areaWidth = BASE_WIDTH        -- centred text uses the layout width
end

function Screen.endUI()
    lg.pop()
    PixelFont.areaWidth = nil
end

-- view pixels -> menu layout pixels
function Screen.toUI(x, y)
    return x - Screen.uiX, y - Screen.uiY
end

-- start drawing the game (everything in view pixels)
function Screen.beginGame()
    lg.setCanvas(canvas)
    lg.clear(BACKGROUND_COLOR)
end

-- finish: put the game on screen, then the touch buttons on top
function Screen.endGame()
    lg.setCanvas()
    lg.push()
    lg.origin()
    lg.scale(1 / Screen.dpi)          -- from here on, 1 unit = 1 real pixel

    lg.clear(Palette.get('K'))

    -- portrait: a console-style panel behind the buttons
    if Screen.portrait then
        local c = Screen.controlArea
        Palette.set('D')
        lg.rectangle('fill', c.x, c.y, c.w, c.h)
        Palette.set('d')
        lg.rectangle('fill', c.x, c.y, c.w, Screen.scale)
    end

    lg.setColor(1, 1, 1, 1)
    lg.draw(canvas, Screen.gameX, Screen.gameY, 0, Screen.scale, Screen.scale)

    TouchControls.render()

    lg.pop()
    lg.setColor(1, 1, 1, 1)
end
