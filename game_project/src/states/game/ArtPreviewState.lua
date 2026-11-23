--[[
    Inflate - ArtPreviewState (temporary, for checking the art)
    Page 1: palette, ball sizes + frames, tiles and objects.
    Page 2: background, pixel font, sound player.
    Left/Right = page, Up/Down + Enter = play sound, Esc = back.
]]

ArtPreviewState = Class{__includes = BaseState}

local lg = love.graphics

function ArtPreviewState:init()
    self.page = 1
    self.time = 0
    self.soundIndex = 1
end

function ArtPreviewState:update(dt)
    self.time = self.time + dt
    local kp = love.keyboard.wasPressed
    if kp('escape') then gStateMachine:change('start') return end
    if kp('left') or kp('right') then self.page = 3 - self.page end

    if self.page == 2 then
        local n = #SoundGen.order
        if kp('up') then self.soundIndex = (self.soundIndex - 2) % n + 1 end
        if kp('down') then self.soundIndex = self.soundIndex % n + 1 end
        if kp('return') or kp('space') then
            local s = gSounds[SoundGen.order[self.soundIndex]]
            s:stop(); s:play()
        end
    end
end

local function label(text, x, y)
    PixelFont.print(text, x, y, {color = 'Y'})
end

function ArtPreviewState:renderPage1()

    -- palette swatches
    label('PALETTE', 6, 4)
    for i = 1, #Palette.order do
        local e = Palette.order[i]
        local x = 6 + (i - 1) * 19
        Palette.set(e[1])
        lg.rectangle('fill', x, 14, 16, 12)
        Palette.set('K')
        lg.rectangle('line', x + 0.5, 14.5, 15, 11)
        PixelFont.print(e[1], x + 5, 28, {color = 'g'})
    end

    -- ball: small / normal / big, frames round / squash / stretch
    label('BALL', 6, 42)
    local x = 6
    for _, size in ipairs({'small', 'normal', 'big'}) do
        for f = 1, 3 do
            local _, _, w, h = gFrames['ball-' .. size][f]:getViewport()
            SpriteBuilder.draw('ball-' .. size, f, x, 80 - h)
            x = x + w + 6
        end
        x = x + 10
    end

    -- tiles and objects (all frames)
    label('TILES + OBJECTS', 6, 90)
    local items = {
        {'ground-top', 1}, {'ground', 1}, {'stone', 1}, {'cracked', 1}, {'spikes', 1},
        {'pump', 1}, {'pump', 2}, {'gem', 1}, {'gem', 2},
        {'crawler', 1}, {'crawler', 2}, {'icon-air', 1}, {'flag', 1}, {'flag', 2},
    }
    x = 6
    for i = 1, #items do
        local name, f = items[i][1], items[i][2]
        local _, _, w, h = gFrames[name][f]:getViewport()
        SpriteBuilder.draw(name, f, x, 134 - h)
        x = x + w + 5
    end

    -- a small tiled scene to see how tiles join
    label('TILED', 6, 140)
    for i = 0, 5 do
        SpriteBuilder.draw('ground-top', 1, 6 + i * 16, 150)
    end
    SpriteBuilder.draw('spikes', 1, 6 + 6 * 16, 150)
    SpriteBuilder.draw('ground-top', 1, 6 + 7 * 16, 150)
    SpriteBuilder.draw('stone', 1, 150, 134)
    SpriteBuilder.draw('stone', 1, 166, 134)
    SpriteBuilder.draw('stone', 1, 150, 150)
    SpriteBuilder.draw('cracked', 1, 166, 150)
    SpriteBuilder.draw('stone', 1, 182, 150)
end

function ArtPreviewState:renderPage2()

    -- font sample panel
    Palette.set('K', 0.75)
    lg.rectangle('fill', 4, 4, 312, 44)
    PixelFont.print('ABCDEFGHIJKLMNOPQRSTUVWXYZ', 8, 8)
    PixelFont.print("0123456789 .,!?:-+/'()<>=%#", 8, 18)
    PixelFont.print('SCALE 2', 8, 28, {scale = 2, color = 'Y', shadow = 'r'})
    PixelFont.print('OUTLINE', 110, 30, {color = 'C', outline = 'K'})

    -- sound list
    Palette.set('K', 0.75)
    -- two columns of 8 so every sound fits on screen
    local PER_COL = 8
    lg.rectangle('fill', 4, 52, 140, 4 + PER_COL * 9)
    for i, name in ipairs(SoundGen.order) do
        local selected = (i == self.soundIndex)
        local col, row = math.floor((i - 1) / PER_COL), (i - 1) % PER_COL
        PixelFont.print((selected and '>' or ' ') .. name, 8 + col * 68, 55 + row * 9,
            {color = selected and 'Y' or 'W'})
    end
    PixelFont.print('UP/DOWN + ENTER: PLAY', 150, 56, {color = 'W', outline = 'K'})

    -- sprites for checkpoints, springs, keys, doors and cave rock
    Palette.set('K', 0.75)
    lg.rectangle('fill', 4, 136, 312, 30)
    local items = {
        {'checkpoint', 1}, {'checkpoint', 2}, {'spring', 1}, {'spring', 2}, {'key', 1},
        {'door', 1}, {'rock-top', 1}, {'rock', 1},
    }
    local x = 8
    lg.setColor(1, 1, 1, 1)
    for i = 1, #items do
        local name, f = items[i][1], items[i][2]
        local _, _, w, h = gFrames[name][f]:getViewport()
        SpriteBuilder.draw(name, f, x, 160 - h)
        x = x + w + 6
    end
end

function ArtPreviewState:render()
    if self.page == 1 then
        Palette.set('D')
        lg.rectangle('fill', 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
    else
        Background.render(self.time * 30, self.time)
    end
    Screen.beginUI()
    if self.page == 1 then self:renderPage1() else self:renderPage2() end
    PixelFont.print('PAGE ' .. self.page .. '/2   <- ->   ESC: BACK', 0, BASE_HEIGHT - 10,
        {align = 'right', width = BASE_WIDTH - 4, color = 'W', outline = 'K'})
    lg.setColor(1, 1, 1, 1)
    Screen.endUI()
end
