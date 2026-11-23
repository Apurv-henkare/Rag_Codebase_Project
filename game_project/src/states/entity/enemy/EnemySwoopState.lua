--[[
    Inflate - EnemySwoopState (cave bat, jungle beetle)
    Dives in a straight line to where the ball was, then flies back up to its
    spot on the ceiling and hangs there again (after a short rest).
    Flies through the air only (the path was clear when it started).

    params = { x, y }   the point it dives to
]]

EnemySwoopState = Class{__includes = BaseState}

local msqrt, mabs = math.sqrt, math.abs

function EnemySwoopState:init(enemy)
    self.enemy = enemy
    self.timer = 0
    self.diving = true
end

function EnemySwoopState:enter(params)
    local e = self.enemy
    e.harmless = false
    self.tx, self.ty = params.x, params.y
    gSounds['swoop']:stop(); gSounds['swoop']:play()
end

function EnemySwoopState:update(dt)
    local e = self.enemy
    self.timer = self.timer + dt

    local tx, ty, speed
    if self.diving then
        tx, ty, speed = self.tx, self.ty, BAT_SWOOP_SPEED
    else
        tx, ty, speed = e.homeX + e.width / 2, e.homeY + e.height / 2, BAT_RETURN_SPEED
    end

    local dx, dy = tx - e:centerX(), ty - e:centerY()
    local d = msqrt(dx * dx + dy * dy)
    local step = speed * dt
    if d <= step then
        e.x, e.y = tx - e.width / 2, ty - e.height / 2
        if self.diving then
            self.diving = false
        else
            e.swoopCooldown = BAT_COOLDOWN
            e:changeState(e.restState)
            return
        end
    else
        e.x = e.x + dx / d * step
        e.y = e.y + dy / d * step
    end
    if self.diving and self.timer > BAT_DIVE_TIME then self.diving = false end

    if mabs(dx) > 0.5 then e.direction = (dx < 0) and -1 or 1 end
    e.animation:update(dt)
    e.frame = e.animation:getCurrentFrame()
end
