--[[
    Inflate - Menu
    A vertical list of options: Up/Down (or W/S) to move, Enter/Space to pick.
    Tapping (or clicking) an option picks it straight away.

    Menu{ items = { {text = 'PLAY', onSelect = function() ... end}, ... } }
    An item with disabled = true is shown greyed out and can't be picked.
]]

Menu = Class{}

local SPACING = 11

function Menu:init(def)
    self.items = def.items
    self.selected = 1
    self.area = nil        -- {x, y, width} from the last render, for taps
end

function Menu:move(step)
    local n = #self.items
    local i = self.selected
    for _ = 1, n do
        i = (i - 1 + step) % n + 1
        if not self.items[i].disabled then break end
    end
    if i ~= self.selected then
        self.selected = i
        gSounds['select']:stop(); gSounds['select']:play()
    end
end

function Menu:pick(i)
    local item = self.items[i]
    if item and not item.disabled then
        self.selected = i
        gSounds['select']:stop(); gSounds['select']:play()
        item.onSelect()
    end
end

function Menu:update()
    -- tap on an option
    if self.area then
        local a = self.area
        local top = a.y - 2
        local gx, gy = TouchControls.consumeTap({a.x, top, a.width, #self.items * SPACING})
        if gx then
            self:pick(math.floor((gy - top) / SPACING) + 1)
            return
        end

        -- mouse hovering over an option highlights it
        local hx, hy = TouchControls.hover()
        if hx and hx >= a.x and hx < a.x + a.width and hy >= top and hy < top + #self.items * SPACING then
            local i = math.floor((hy - top) / SPACING) + 1
            local item = self.items[i]
            if i ~= self.selected and item and not item.disabled then
                self.selected = i
                gSounds['select']:stop(); gSounds['select']:play()
            end
        end
    end

    local kp = love.keyboard.wasPressed
    if kp('up') or kp('w') then self:move(-1)
    elseif kp('down') or kp('s') then self:move(1)
    elseif kp('return') or kp('kpenter') or kp('space') then
        self:pick(self.selected)
    end
end

-- centred in the area [x, x + width], first item at y
function Menu:render(x, y, width)
    self.area = { x = x, y = y, width = width }
    for i, item in ipairs(self.items) do
        local selected = (i == self.selected)
        local text = selected and ('> ' .. item.text .. ' <') or item.text
        local color = item.disabled and 'd' or (selected and 'Y' or 'W')
        PixelFont.print(text, x, y + (i - 1) * SPACING,
            {align = 'center', width = width, color = color, outline = 'K'})
    end
end

function Menu:height()
    return #self.items * SPACING
end
