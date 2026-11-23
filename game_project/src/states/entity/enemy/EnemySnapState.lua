--[[
    Inflate - EnemySnapState (snapper plant)
    Can't be hurt and never moves. Closed it is harmless. When the ball comes
    close it opens its mouth (the warning), then bites - reaching a tile up,
    so jumping over it at the wrong moment hurts too. After a bite it droops,
    tired: that is the moment to roll past.

      idle -> open -> bite -> tired -> idle
]]

EnemySnapState = Class{__includes = BaseState}

local msqrt = math.sqrt

function EnemySnapState:init(enemy)
    self.enemy = enemy
end

function EnemySnapState:enter()
    local e = self.enemy
    self.phase = 'idle'
    self.timer = 0
    e.harmless = true
    e.reach = 0
    e.frame = 1
end

function EnemySnapState:update(dt)
    local e = self.enemy
    local phase = self.phase
    self.timer = self.timer - dt

    if phase == 'idle' then
        e.frame = 1
        local ball = e.target
        if ball and not ball.dead then
            local dx, dy = ball:centerX() - e:centerX(), ball:centerY() - e.y
            if dx * dx + dy * dy < PLANT_SIGHT * PLANT_SIGHT then
                e.direction = (dx < 0) and -1 or 1
                self.phase, self.timer = 'open', PLANT_WARN_TIME
            end
        end
    elseif phase == 'open' then
        e.frame = 2
        if self.timer <= 0 then
            self.phase, self.timer = 'bite', PLANT_BITE_TIME
            e.harmless = false
            e.reach = PLANT_REACH
            if e:nearBall(200) then gSounds['snap']:stop(); gSounds['snap']:play() end
        end
    elseif phase == 'bite' then
        e.frame = 3
        if self.timer <= 0 then
            self.phase, self.timer = 'tired', PLANT_TIRED_TIME
            e.harmless = true
            e.reach = 0
        end
    else -- tired
        e.frame = 4
        if self.timer <= 0 then self.phase = 'idle' end
    end
end
