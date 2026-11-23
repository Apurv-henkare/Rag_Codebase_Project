--[[
    Inflate - Animation
    Steps through a list of frame numbers at a fixed interval.

    Animation{ frames = {1, 2}, interval = 0.25 }
]]

Animation = Class{}

function Animation:init(def)
    self.frames = def.frames
    self.interval = def.interval or 0.2
    self.timer = 0
    self.currentFrame = 1
end

function Animation:update(dt)
    local n = #self.frames
    if n > 1 then
        self.timer = self.timer + dt
        while self.timer >= self.interval do
            self.timer = self.timer - self.interval
            self.currentFrame = self.currentFrame % n + 1
        end
    end
end

function Animation:getCurrentFrame()
    return self.frames[self.currentFrame]
end

-- start somewhere random in the loop so identical objects don't animate in sync
function Animation:randomize()
    self.currentFrame = math.random(#self.frames)
    self.timer = math.random() * self.interval
end
