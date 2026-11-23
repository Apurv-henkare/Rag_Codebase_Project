--[[
    Inflate - LevelSelectState
    Level cards in rows of 6, 12 per page (arrows at the sides change page):
    locked/unlocked, best gems. Below: name + best time.
    Arrows = choose, Enter = play, Esc = back to the title.

    params = { selected = n }  (optional)
]]

LevelSelectState = Class{__includes = BaseState}

local lg = love.graphics
local mfloor = math.floor

local CARD_W, CARD_H = 44, 44
local CARD_GAP_X, CARD_GAP_Y = 6, 8
local PER_ROW = 6
local PER_PAGE = 12
local CARD_Y = 32
local PAGES = math.ceil(LEVEL_COUNT / PER_PAGE)

-- page arrows for touch / mouse (left and right edge, beside the cards)
local PREV_AREA = {0, CARD_Y, 12, 96}
local NEXT_AREA = {BASE_WIDTH - 12, CARD_Y, 12, 96}

local function pageOf(n) return mfloor((n - 1) / PER_PAGE) end

-- number logos are built once and reused
local numberLogos = nil
local function getNumberLogo(n)
    if not numberLogos then
        numberLogos = {}
        for i = 1, LEVEL_COUNT do
            numberLogos[i] = PixelFont.makeLogo(tostring(i), 2, {'W', 'Y', 'O', 'K', 'r'})
        end
    end
    return numberLogos[n]
end

-- top-left corner of card n
local function cardPosition(n)
    local totalW = PER_ROW * CARD_W + (PER_ROW - 1) * CARD_GAP_X
    local startX = mfloor((BASE_WIDTH - totalW) / 2)
    local i = (n - 1) % PER_PAGE
    local col = i % PER_ROW
    local row = mfloor(i / PER_ROW)
    return startX + col * (CARD_W + CARD_GAP_X), CARD_Y + row * (CARD_H + CARD_GAP_Y)
end

-- "< BACK" button for touch screens (top-left)
local BACK_AREA = {0, 0, 48, 26}

local function formatTime(seconds)
    return string.format('%d:%02d', mfloor(seconds / 60), mfloor(seconds % 60))
end

function LevelSelectState:enter(params)
    self.time = 0
    self.selected = (params and params.selected) or SaveData.continueLevel()
    self.info = {}
    for n = 1, LEVEL_COUNT do
        self.info[n] = LevelMaker.info(n)
    end
end

function LevelSelectState:update(dt)
    self.time = self.time + dt
    local kp = love.keyboard.wasPressed

    if kp('escape') or TouchControls.consumeTap(BACK_AREA) then
        gSounds['select']:stop(); gSounds['select']:play()
        gStateMachine:change('start')
        return
    end

    -- page arrows (only when there is more than one page)
    local page = pageOf(self.selected)
    if PAGES > 1 then
        local turn = 0
        if TouchControls.consumeTap(PREV_AREA) then turn = -1 end
        if TouchControls.consumeTap(NEXT_AREA) then turn = 1 end
        if turn ~= 0 then
            local np = (page + turn) % PAGES
            self.selected = math.min(LEVEL_COUNT, np * PER_PAGE + 1)
            gSounds['select']:stop(); gSounds['select']:play()
            page = np
        end
    end
    local first, last = page * PER_PAGE + 1, math.min(LEVEL_COUNT, (page + 1) * PER_PAGE)

    -- mouse hovering over a card selects it
    local hx, hy = TouchControls.hover()
    if hx then
        for n = first, last do
            local cx, cy = cardPosition(n)
            if n ~= self.selected and hx >= cx and hx < cx + CARD_W and hy >= cy and hy < cy + CARD_H then
                self.selected = n
                gSounds['select']:stop(); gSounds['select']:play()
                break
            end
        end
    end

    -- tap a card to choose it, tap it again to play (a click plays straight away
    -- when the mouse already selected it by hovering)
    local playNow = false
    local gx, gy = TouchControls.consumeTap()
    if gx then
        for n = first, last do
            local cx, cy = cardPosition(n)
            if gx >= cx - 2 and gx < cx + CARD_W + 2 and gy >= cy - 4 and gy < cy + CARD_H + 2 then
                if n == self.selected then
                    playNow = true
                else
                    self.selected = n
                    gSounds['select']:stop(); gSounds['select']:play()
                end
                break
            end
        end
    end

    local step = 0
    if kp('left') or kp('a') then step = -1 end
    if kp('right') or kp('d') then step = 1 end
    if kp('up') or kp('w') then step = -PER_ROW end
    if kp('down') or kp('s') then step = PER_ROW end
    if step ~= 0 then
        local n = clamp(self.selected + step, 1, LEVEL_COUNT)
        if n ~= self.selected then
            self.selected = n
            gSounds['select']:stop(); gSounds['select']:play()
        end
    end

    if playNow or kp('return') or kp('kpenter') or kp('space') then
        if SaveData.isUnlocked(self.selected) then
            gSounds['select']:stop(); gSounds['select']:play()
            gStateMachine:change('play', { level = self.selected })
        else
            gSounds['hurt']:stop(); gSounds['hurt']:play()
        end
    end
end

function LevelSelectState:renderCard(n, x, y)
    local unlocked = SaveData.isUnlocked(n)
    local selected = (n == self.selected)
    if selected then y = y - 3 end    -- selected card lifts up

    -- border, body, top highlight
    Palette.set(selected and 'Y' or 'K')
    lg.rectangle('fill', x - 1, y - 1, CARD_W + 2, CARD_H + 2)
    Palette.set(unlocked and 'T' or 'D')
    lg.rectangle('fill', x, y, CARD_W, CARD_H)
    Palette.set(unlocked and 'G' or 'd')
    lg.rectangle('fill', x, y, CARD_W, 1)

    if unlocked then
        local logo = getNumberLogo(n)
        lg.setColor(1, 1, 1, 1)
        lg.draw(logo, x + mfloor((CARD_W - logo:getWidth()) / 2), y + 5)

        local rec = SaveData.getRecord(n)
        local text = (rec and rec.gems or '-') .. '/' .. self.info[n].gems
        local tw = PixelFont.width(text)
        local gx = x + mfloor((CARD_W - (tw + 10)) / 2)
        SpriteBuilder.draw('gem', 1, gx, y + 31)
        PixelFont.print(text, gx + 10, y + 32, {color = 'W'})
    else
        local _, _, lw, lh = gFrames['icon-lock'][1]:getViewport()
        SpriteBuilder.draw('icon-lock', 1, x + mfloor((CARD_W - lw) / 2), y + mfloor((CARD_H - lh) / 2))
    end
end

function LevelSelectState:render()
    Background.render(self.time * 10, self.time)

    Screen.beginUI()
    PixelFont.print('SELECT LEVEL', 0, 12, {align = 'center', color = 'Y', outline = 'K'})

    local rows = PER_PAGE / PER_ROW
    local page = pageOf(self.selected)
    local first, last = page * PER_PAGE + 1, math.min(LEVEL_COUNT, (page + 1) * PER_PAGE)
    for n = first, last do
        self:renderCard(n, cardPosition(n))
    end
    if PAGES > 1 then
        -- page arrows (blink a little) and "PAGE 1/2" under the title
        local on = mfloor(self.time * 2) % 2 == 0
        local ay = CARD_Y + CARD_H + 2
        PixelFont.print('<', 3, ay, {color = on and 'Y' or 'W', outline = 'K'})
        PixelFont.print('>', BASE_WIDTH - 9, ay, {color = on and 'Y' or 'W', outline = 'K'})
        PixelFont.print('PAGE ' .. (page + 1) .. '/' .. PAGES, 0, 21, {align = 'center', color = 'g', outline = 'K'})
    end

    -- details of the selected level
    local n = self.selected
    local y = CARD_Y + rows * (CARD_H + CARD_GAP_Y) + 2
    if SaveData.isUnlocked(n) then
        PixelFont.print(self.info[n].name, 0, y, {align = 'center', color = 'W', outline = 'K'})
        local rec = SaveData.getRecord(n)
        local line = rec and ('BEST TIME  ' .. formatTime(rec.time)) or 'NOT COMPLETED YET'
        PixelFont.print(line, 0, y + 11, {align = 'center', color = 'g', outline = 'K'})
    else
        PixelFont.print('LOCKED', 0, y, {align = 'center', color = 'g', outline = 'K'})
        PixelFont.print('FINISH LEVEL ' .. (n - 1) .. ' TO UNLOCK', 0, y + 11,
            {align = 'center', color = 'g', outline = 'K'})
    end

    if isTouchUI() then
        PixelFont.print('< BACK', 6, 12, {color = 'W', outline = 'K'})
        PixelFont.print('TAP A LEVEL, TAP AGAIN TO PLAY', 0, BASE_HEIGHT - 11,
            {align = 'center', color = 'W', outline = 'K'})
    else
        PixelFont.print('ARROWS: CHOOSE   ENTER: PLAY   ESC: BACK', 0, BASE_HEIGHT - 11,
            {align = 'center', color = 'W', outline = 'K'})
    end
    lg.setColor(1, 1, 1, 1)
    Screen.endUI()
end
