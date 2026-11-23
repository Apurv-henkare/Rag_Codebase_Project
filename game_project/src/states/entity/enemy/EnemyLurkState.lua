--[[
    Inflate - EnemyLurkState (snake)
    Hides in the grass (only its eyes show, harmless). When the ball comes
    close on its floor it raises its head (the warning), lunges forward,
    stays up for a moment, then slides back to its spot and hides again.

      hide -> rise -> lunge -> out -> back -> hide
]]

EnemyLurkState = Class{__includes = BaseState}

local mabs = math.abs

function EnemyLurkState:init(enemy)
    self.enemy = enemy
end

function EnemyLurkState:enter()
    local e = self.enemy
    self.phase = 'hide'
    self.timer = 0
    self.cool = SNAKE_COOLDOWN * 0.5
    self.homeX = e.x
    e.dx = 0
    e.harmless = true
    e.frame = 1
end

-- move sideways by dx, stopping at walls and ledges. Returns false if blocked.
local function slide(e, dx)
    local tm = e.tileMap
    local newX, wall = tm:sweepX(e.x, e.y, e.width, e.height, dx)
    if wall or newX < 0 or newX > tm.width - e.width then return false end
    local frontX = dx > 0 and (newX + e.width + 1) or (newX - 1)
    if e.grounded and not e:floorAhead(frontX) then return false end
    e.x = newX
    return true
end

function EnemyLurkState:update(dt)
    local e = self.enemy
    local ball = e.target
    e:applyGravity(dt)
    local phase = self.phase

    if phase == 'hide' then
        e.frame = 1
        e.harmless = true
        self.cool = self.cool - dt
        if self.cool <= 0 and e:seesOnFloor(ball, SNAKE_SIGHT) then
            e.direction = (ball:centerX() < e:centerX()) and -1 or 1
            e.harmless = false
            self.phase, self.timer = 'rise', SNAKE_RISE_TIME
            gSounds['hiss']:stop(); gSounds['hiss']:play()
        end

    elseif phase == 'rise' then
        e.frame = 2
        self.timer = self.timer - dt
        if self.timer <= 0 then self.phase, self.dist = 'lunge', 0 end

    elseif phase == 'lunge' then
        e.frame = 3
        local step = SNAKE_LUNGE_SPEED * dt
        if not slide(e, e.direction * step) then
            self.dist = SNAKE_LUNGE_DIST
        else
            self.dist = self.dist + step
        end
        if self.dist >= SNAKE_LUNGE_DIST then self.phase, self.timer = 'out', SNAKE_OUT_TIME end

    elseif phase == 'out' then
        e.frame = 2
        self.timer = self.timer - dt
        if self.timer <= 0 then self.phase = 'back' end

    else -- back: slide home, then hide
        e.frame = 2
        local dx = self.homeX - e.x
        local step = 40 * dt
        if mabs(dx) <= step or not slide(e, (dx > 0 and 1 or -1) * step) then
            if mabs(dx) <= step then e.x = self.homeX end
            self.phase = 'hide'
            self.cool = SNAKE_COOLDOWN
            e.harmless = true
        end
    end
end
