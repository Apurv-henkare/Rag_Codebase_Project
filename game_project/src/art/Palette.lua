--[[
    Inflate - Palette
    The ONLY colours the game uses. Every sprite grid letter maps to one entry.
    Keeping to one small palette is what makes pixel art look consistent.

    '.' in a sprite grid means transparent.
]]

Palette = {}

local function hex(h)
    return {
        tonumber(h:sub(1, 2), 16) / 255,
        tonumber(h:sub(3, 4), 16) / 255,
        tonumber(h:sub(5, 6), 16) / 255,
        1
    }
end

-- letter -> hex. Order here is the order shown in the art preview.
Palette.order = {
    {'K', '1a1c2c', 'outline / black'},
    {'D', '333c57', 'deep slate'},
    {'d', '566c86', 'slate'},
    {'g', '94b0c2', 'light slate'},
    {'W', 'f4f4f4', 'white'},
    {'r', '7a2440', 'maroon'},
    {'R', 'c83c48', 'red'},
    {'O', 'ef7d57', 'orange'},
    {'Y', 'ffcd75', 'yellow'},
    {'b', '5b3a34', 'dark brown'},
    {'n', '9a6348', 'brown'},
    {'T', '257179', 'teal'},
    {'G', '38b764', 'green'},
    {'L', 'a7f070', 'lime'},
    {'S', '41a6f6', 'sky'},
    {'C', '73eff7', 'cyan'},
    {'p', '482a5e', 'deep purple (crystal cave)'},
    {'v', 'a463e0', 'violet (crystal cave)'},
    {'j', '1e5236', 'deep jungle green (wild falls)'},
}

Palette.colors = {}
for i = 1, #Palette.order do
    local e = Palette.order[i]
    Palette.colors[e[1]] = hex(e[2])
end

-- returns the {r,g,b,a} table for a letter (errors on a typo so mistakes show up early)
function Palette.get(letter)
    local c = Palette.colors[letter]
    assert(c, 'Unknown palette letter: ' .. tostring(letter))
    return c
end

-- shortcut: love.graphics.setColor with a palette letter and optional alpha
function Palette.set(letter, alpha)
    local c = Palette.get(letter)
    love.graphics.setColor(c[1], c[2], c[3], alpha or 1)
end
