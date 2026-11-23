--[[
    Inflate - TouchControls
    On-screen pixel-art buttons for phones and tablets, plus taps for menus.

      left / right   bottom-left (slide your thumb between them)
      jump           big button bottom-right
      grow / shrink  small buttons next to jump
      pause          small button at the top

    - Multi-touch: roll and jump at the same time.
    - The buttons appear after the first touch, so the PC version looks the same.
    - They show only while playing (PlayState:wantsTouchControls()).
    - Taps that miss the buttons become "taps" in game pixels, used by menus
      (TouchControls.consumeTap). Mouse clicks also make taps on PC.
    - F2 on PC: pretend to be a touch screen (the mouse acts as one finger).

    Game code asks through isInputDown / wasInputPressed in main.lua.
]]

TouchControls = {
    visible = false,       -- true once the screen has been touched
    gameplay = false,      -- true while the buttons should work (set in main.lua)
    emulate = false,       -- F2: mouse acts as a finger
}

local lg = love.graphics
local mfloor, mmax, mmin = math.floor, math.max, math.min

local touches = {}         -- id -> { x, y } in screen pixels
local buttons = {}         -- laid out by TouchControls.layout
local held = {}            -- action -> true while a finger is on it
local pressed = {}         -- action -> true on the frame it was pressed
local queued = {}          -- presses that happened between updates (quick taps)
local taps = {}            -- list of {x, y} in game pixels, cleared each frame
local portraitMode = false

-- sprite sizes (in button pixels; drawn scaled up by a whole number)
local BIG, SMALL, TINY = 20, 13, 11

---------------------------------------------------------------------------
-- LAYOUT
---------------------------------------------------------------------------

-- pad: extra touch area around the drawing, as a fraction of its size
local function makeButton(action, sprite, x, y, size, cs, pad)
    local px = mfloor(size * cs * (pad or 0.4))
    return {
        action = action, sprite = sprite, x = x, y = y,
        size = size * cs, scale = cs,
        -- hit area: bigger than the drawing (fingers are not precise)
        hx = x - px, hy = y - px,
        hw = size * cs + px * 2, hh = size * cs + px * 2,
    }
end

-- ctrl: area for the buttons {x, y, w, h} in screen pixels
function TouchControls.layout(ctrl, portrait)
    portraitMode = portrait
    local w, h = ctrl.w, ctrl.h

    -- button scale: about 19% of the screen height in landscape (a good
    -- thumb size on phones), about 33% of the panel in portrait
    local cs
    if portrait then
        cs = mmax(1, mfloor(mmin(h * 0.33, w * 0.22) / BIG))
    else
        cs = mmax(1, mfloor(h * 0.19 / BIG))
    end
    -- the whole row (margins, 3 big + 1 small button, gaps, padding) is
    -- about 110 x cs wide - keep it on narrow screens
    cs = mmax(1, mmin(cs, mfloor(w / 110)))

    -- grow / shrink are drawn a quarter smaller than the other buttons
    local scs = mmax(1, mfloor(cs * 0.75 + 0.5))
    local big, small = BIG * cs, SMALL * scs
    local margin = mfloor(big * 0.35)
    local gap = 5 * cs
    local bottom = ctrl.y + h

    local by
    if portrait then
        by = ctrl.y + mfloor((h - big) / 2)
    else
        by = bottom - margin - big
    end

    local leftX = ctrl.x + margin
    local rightX = leftX + big + gap
    local jumpX = ctrl.x + w - margin - big
    local sideX = jumpX - gap - small
    local mid = by + mfloor(big / 2)

    buttons = {
        makeButton('left', 'btn-left', leftX, by, BIG, cs),
        makeButton('right', 'btn-right', rightX, by, BIG, cs),
        makeButton('jump', 'btn-jump', jumpX, by, BIG, cs),
        makeButton('grow', 'btn-grow', sideX, mid - small - cs, SMALL, scs),
        makeButton('shrink', 'btn-shrink', sideX, mid + cs, SMALL, scs),
    }

    local tiny = TINY * cs
    local pauseY = ctrl.y + mfloor(margin / 2)
    buttons[#buttons + 1] = makeButton('pause', 'btn-pause', ctrl.x + mfloor((w - tiny) / 2), pauseY, TINY, cs)

    local l, r, j = buttons[1], buttons[2], buttons[3]
    local pad = mfloor(big * 0.4)

    -- left / right: big zones that reach the left edge and the bottom of the
    -- screen; they share the line between them, so sliding switches cleanly
    local split = mfloor((l.x + l.size + r.x) / 2)
    -- (never above the pause button, so it can't steal pause taps)
    local pb = buttons[#buttons]
    local zoneTop = mmax(by - pad, pb.hy + pb.hh)
    l.hx, l.hy, l.hw, l.hh = ctrl.x, zoneTop, split - ctrl.x, bottom - zoneTop
    r.hx, r.hy, r.hw, r.hh = split, zoneTop, (r.x + r.size + pad) - split, bottom - zoneTop

    -- jump: from a bit left of the button to the right edge, down to the bottom
    j.hx, j.hy = jumpX - pad, zoneTop
    j.hw, j.hh = ctrl.x + w - j.hx, bottom - zoneTop

    -- the grow / shrink pair splits the space between them the same way
    local g, s = buttons[4], buttons[5]
    local splitY = mfloor((g.y + g.size + s.y) / 2)
    g.hh = splitY - g.hy
    s.hh = (s.hy + s.hh) - splitY
    s.hy = splitY
    -- and they must not steal touches from the jump or right button zones
    for _, b in ipairs({g, s}) do
        b.hw = mmin(b.hw, j.hx - b.hx)
        local rEdge = r.hx + r.hw
        if b.hx < rEdge then
            b.hw = b.hw - (rEdge - b.hx)
            b.hx = rEdge
        end
    end
end

local function buttonAt(x, y)
    for i = 1, #buttons do
        local b = buttons[i]
        if x >= b.hx and x < b.hx + b.hw and y >= b.hy and y < b.hy + b.hh then
            return b
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- INPUT EVENTS (called from main.lua; x, y in LÖVE units)
---------------------------------------------------------------------------

function TouchControls.pressed(id, x, y)
    local px, py = Screen.toPixels(x, y)
    touches[id] = { x = px, y = py }

    if TouchControls.gameplay then
        local b = buttonAt(px, py)
        if b then
            queued[b.action] = true
            return
        end
    end

    -- not on a button: a tap for menus
    local gx, gy = Screen.toGame(px, py)
    taps[#taps + 1] = { x = gx, y = gy }
end

function TouchControls.moved(id, x, y)
    local t = touches[id]
    if t then t.x, t.y = Screen.toPixels(x, y) end
end

function TouchControls.released(id)
    touches[id] = nil
end

function love.touchpressed(id, x, y)
    TouchControls.visible = true
    TouchControls.pressed(id, x, y)
end

function love.touchmoved(id, x, y)
    TouchControls.moved(id, x, y)
end

function love.touchreleased(id)
    TouchControls.released(id)
end

-- mouse: a finger when emulating (F2), otherwise clicks are just taps
function love.mousepressed(x, y, button, istouch)
    if istouch or button ~= 1 then return end      -- real touches come through love.touch*
    if TouchControls.emulate then
        TouchControls.pressed('mouse', x, y)
    else
        local gx, gy = Screen.toGame(Screen.toPixels(x, y))
        taps[#taps + 1] = { x = gx, y = gy }
    end
end

local hoverX, hoverY = nil, nil     -- mouse position (game pixels) if it moved this frame

function love.mousemoved(x, y, dx, dy, istouch)
    if istouch then return end
    if TouchControls.emulate then
        TouchControls.moved('mouse', x, y)
    end
    -- menus highlight what the mouse is over (also in F2 test mode)
    hoverX, hoverY = Screen.toGame(Screen.toPixels(x, y))
end

-- where the mouse is pointing, only on frames when it moved (so the
-- keyboard can still change the selection while the mouse sits still)
function TouchControls.hover()
    if not hoverX then return nil end
    return Screen.toUI(hoverX, hoverY)        -- menu layout pixels, like taps
end

function love.mousereleased(x, y, button, istouch)
    if not istouch and button == 1 then TouchControls.released('mouse') end
end

function TouchControls.toggleEmulation()
    TouchControls.emulate = not TouchControls.emulate
    TouchControls.visible = TouchControls.emulate
    touches['mouse'] = nil
end

---------------------------------------------------------------------------
-- PER FRAME
---------------------------------------------------------------------------

-- forget every finger and button (screen rotated / resized, app lost focus)
function TouchControls.reset()
    for id in pairs(touches) do touches[id] = nil end
    for k in pairs(held) do held[k] = nil end
    for k in pairs(queued) do queued[k] = nil end
end

-- the fingers on the screen right now, straight from LÖVE. If the browser
-- loses a "finger lifted" message (fullscreen, rotation...), the finger is
-- dropped here anyway, so a button can never get stuck down.
local function syncTouches()
    local ids = love.touch.getTouches()
    local live = {}
    for i = 1, #ids do
        local id = ids[i]
        local x, y = love.touch.getPosition(id)
        live[id] = true
        local t = touches[id]
        if not t then t = {}; touches[id] = t end
        t.x, t.y = Screen.toPixels(x, y)
    end
    for id in pairs(touches) do
        if id ~= 'mouse' and not live[id] then touches[id] = nil end
    end
end

-- before the game updates: work out which buttons are held / just pressed
function TouchControls.update()
    syncTouches()
    for i = 1, #buttons do
        local action = buttons[i].action
        local was = held[action]
        local now = false
        if TouchControls.gameplay then
            for _, t in pairs(touches) do
                local b = buttonAt(t.x, t.y)
                if b and b.action == action then now = true; break end
            end
        end
        held[action] = now
        pressed[action] = TouchControls.gameplay and ((now and not was) or queued[action] or false)
        queued[action] = nil
    end
end

-- after the game updates
function TouchControls.endFrame()
    taps = {}
    hoverX, hoverY = nil, nil
end

function TouchControls.isDown(action)
    return held[action] == true
end

function TouchControls.wasPressed(action)
    return pressed[action] == true
end

-- the first tap this frame, removed so it's only used once. Positions are in
-- the 320 x 180 MENU layout (see Screen.beginUI) - taps are only used by menus.
-- area (optional): {x, y, w, h} - only a tap inside it counts
function TouchControls.consumeTap(area)
    for i = 1, #taps do
        local t = taps[i]
        t = { x = t.x - Screen.uiX, y = t.y - Screen.uiY }
        if not area or (t.x >= area[1] and t.y >= area[2]
                and t.x < area[1] + area[3] and t.y < area[2] + area[4]) then
            table.remove(taps, i)
            return t.x, t.y
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- DRAWING (screen pixels; called by Screen.endGame)
---------------------------------------------------------------------------

function TouchControls.render()
    if not (TouchControls.visible and TouchControls.gameplay) then return end
    -- in landscape the buttons sit over the game, so they're see-through
    local alphaUp = portraitMode and 1 or 0.45
    local alphaDown = portraitMode and 1 or 0.8
    for i = 1, #buttons do
        local b = buttons[i]
        local down = held[b.action]
        lg.setColor(1, 1, 1, down and alphaDown or alphaUp)
        lg.push()
        lg.translate(b.x, b.y)
        lg.scale(b.scale)
        SpriteBuilder.draw(b.sprite, down and 2 or 1, 0, 0)
        lg.pop()
    end
    lg.setColor(1, 1, 1, 1)
end
