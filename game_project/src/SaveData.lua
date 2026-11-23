--[[
    Inflate - SaveData
    Remembers progress between sessions in the LÖVE save folder
    (Windows: %APPDATA%/LOVE/inflate/save.lua).

    Saved: highest unlocked level, and per level the best gems and best time.

    WEB (love.js): the save file is only reliable when the page closes
    normally, and a browser tab and the installed app can overwrite each
    other's newer progress with an older copy. So on the web the progress is
    ALSO kept by the page (game/play.html, in localStorage):
      - every save prints '@@SAVE@@<progress>'; the page merges it with what
        it has and stores the result at once
      - at start the page passes its progress in as 'websave=<progress>'
    Merging always keeps the best of both (highest unlock, most gems, fastest
    time), so progress can only go up.
    <progress> = "u14|1:9:35.20|2:19:61.05"  (u = unlocked, level:gems:time)
]]

SaveData = {}

local FILE = 'save.lua'

local function defaults()
    return { unlocked = 1, levels = {} }
end

-- keep the better record for level n (most gems, fastest time)
local function mergeLevel(data, n, gems, time)
    if n < 1 or n > LEVEL_COUNT then return end
    local rec = data.levels[n]
    if rec == nil then
        data.levels[n] = { gems = gems, time = time }
    else
        if gems > rec.gems then rec.gems = gems end
        if time < rec.time then rec.time = time end
    end
    -- a finished level always unlocks the next one
    data.unlocked = math.max(data.unlocked, math.min(n + 1, LEVEL_COUNT))
end

-- progress as one short line of text (see the top of this file)
local function encode(data)
    local parts = { 'u' .. data.unlocked }
    for n = 1, LEVEL_COUNT do
        local rec = data.levels[n]
        if rec then parts[#parts + 1] = ('%d:%d:%.2f'):format(n, rec.gems, rec.time) end
    end
    return table.concat(parts, '|')
end

local function mergeText(data, text)
    for part in text:gmatch('[^|]+') do
        local u = part:match('^u(%d+)$')
        if u then
            data.unlocked = math.max(data.unlocked, clamp(tonumber(u), 1, LEVEL_COUNT))
        else
            local n, g, t = part:match('^(%d+):(%d+):([%d%.]+)$')
            if n then mergeLevel(data, tonumber(n), tonumber(g), tonumber(t)) end
        end
    end
end

-- the 'websave=...' start argument from the web page, if any
local function webArgument(args)
    for _, list in ipairs({ args or {}, arg or {} }) do
        for _, a in pairs(list) do
            if type(a) == 'string' then
                local s = a:match('^websave=(.*)$')
                if s then return s end
            end
        end
    end
    return nil
end

-- reads the save file; anything missing or broken falls back to a fresh save.
-- args: the game's start arguments (the web page passes its progress there)
function SaveData.load(args)
    local data = defaults()
    if love.filesystem.getInfo(FILE) then
        local okLoad, chunk = pcall(love.filesystem.load, FILE)
        if okLoad and chunk then
            local okRun, saved = pcall(chunk)
            if okRun and type(saved) == 'table' then
                if type(saved.unlocked) == 'number' then
                    data.unlocked = clamp(math.floor(saved.unlocked), 1, LEVEL_COUNT)
                end
                if type(saved.levels) == 'table' then
                    for n = 1, LEVEL_COUNT do
                        local rec = saved.levels[n]
                        if type(rec) == 'table' and type(rec.gems) == 'number'
                            and type(rec.time) == 'number' then
                            data.levels[n] = { gems = rec.gems, time = rec.time }
                            -- a finished level always unlocks the next one (old saves
                            -- were made when there were fewer levels)
                            data.unlocked = math.max(data.unlocked, math.min(n + 1, LEVEL_COUNT))
                        end
                    end
                end
            end
        end
    end

    -- web: add the progress the page kept (best of both)
    local web = webArgument(args)
    if web then pcall(mergeText, data, web) end

    SaveData.data = data
end

function SaveData.save()
    local d = SaveData.data
    local lines = { 'return {', '    unlocked = ' .. d.unlocked .. ',', '    levels = {' }
    for n = 1, LEVEL_COUNT do
        local rec = d.levels[n]
        if rec then
            lines[#lines + 1] = ('        [%d] = { gems = %d, time = %.2f },'):format(n, rec.gems, rec.time)
        end
    end
    lines[#lines + 1] = '    },'
    lines[#lines + 1] = '}'
    love.filesystem.write(FILE, table.concat(lines, '\n') .. '\n')

    -- web: hand the progress to the page, which merges and stores it at once
    if IS_WEB then print('@@SAVE@@' .. encode(d)) end
end

function SaveData.isUnlocked(n)
    return n <= SaveData.data.unlocked
end

-- best record for a level, or nil if never completed
function SaveData.getRecord(n)
    return SaveData.data.levels[n]
end

-- the level "Continue" should start: highest unlocked
function SaveData.continueLevel()
    return math.min(SaveData.data.unlocked, LEVEL_COUNT)
end

function SaveData.totalBestGems()
    local total = 0
    for n = 1, LEVEL_COUNT do
        local rec = SaveData.data.levels[n]
        if rec then total = total + rec.gems end
    end
    return total
end

-- call when a level is finished. Returns newBestGems, newBestTime (booleans)
function SaveData.recordLevel(n, gems, time)
    local d = SaveData.data
    local rec = d.levels[n]
    local newGems = (rec == nil) or gems > rec.gems
    local newTime = (rec == nil) or time < rec.time
    if rec == nil then
        d.levels[n] = { gems = gems, time = time }
    else
        if newGems then rec.gems = gems end
        if newTime then rec.time = time end
    end
    d.unlocked = math.max(d.unlocked, math.min(n + 1, LEVEL_COUNT))
    SaveData.save()
    return newGems, newTime
end
