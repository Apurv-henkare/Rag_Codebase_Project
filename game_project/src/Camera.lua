--[[
    Inflate - Camera
    Smoothly follows a point, stays inside the level, and always draws at
    whole pixels so tiles never shimmer while scrolling.

    camera:attach() ... draw world ... camera:detach()
]]

Camera = Class{}

local mfloor, mmax, mmin, mexp = math.floor, math.max, math.min, math.exp

function Camera:init(levelWidth, levelHeight)
    self.levelWidth = levelWidth
    self.levelHeight = levelHeight
    self.x = 0
    self.y = 0

    -- screen shake (whole-pixel offsets that fade out)
    self.shakeAmount = 0
    self.shakeTime = 0
    self.shakeDuration = 0
    self.shakeX, self.shakeY = 0, 0
end

-- amount: max offset in pixels; duration: seconds. A stronger shake replaces a weaker one.
function Camera:shake(amount, duration)
    if amount >= self.shakeAmount * (self.shakeTime / math.max(self.shakeDuration, 0.001)) then
        self.shakeAmount = amount
        self.shakeTime = duration
        self.shakeDuration = duration
    end
end

function Camera:updateShake(dt)
    if self.shakeTime > 0 then
        self.shakeTime = self.shakeTime - dt
        local strength = self.shakeAmount * math.max(0, self.shakeTime / self.shakeDuration)
        local s = math.floor(strength + 0.5)
        self.shakeX = math.random(-s, s)
        self.shakeY = math.random(-s, s)
    else
        self.shakeAmount = 0
        self.shakeX, self.shakeY = 0, 0
    end
end

-- keeps the view inside the level. The view size follows the window, so it can
-- be bigger than a level: then the level is centred sideways, and lined up
-- with the BOTTOM of the screen (extra space shows as sky above, never as
-- background below the ground).
function Camera:clamp()
    if self.levelWidth <= VIRTUAL_WIDTH then
        self.x = -(VIRTUAL_WIDTH - self.levelWidth) / 2
    else
        self.x = mmax(0, mmin(self.levelWidth - VIRTUAL_WIDTH, self.x))
    end
    if self.levelHeight <= VIRTUAL_HEIGHT then
        self.y = self.levelHeight - VIRTUAL_HEIGHT
    else
        self.y = mmax(0, mmin(self.levelHeight - VIRTUAL_HEIGHT, self.y))
    end
end

-- jump straight to a point (used when a level starts)
function Camera:snapTo(tx, ty)
    self.x = tx - VIRTUAL_WIDTH / 2
    self.y = ty - VIRTUAL_HEIGHT / 2
    self:clamp()
end

-- ease toward a point; frame-rate independent
function Camera:follow(tx, ty, dt)
    local k = 1 - mexp(-CAMERA_FOLLOW_SPEED * dt)
    self.x = self.x + (tx - VIRTUAL_WIDTH / 2 - self.x) * k
    self.y = self.y + (ty - VIRTUAL_HEIGHT / 2 - self.y) * k
    self:clamp()
end

-- whole-pixel position actually used for drawing (includes shake)
function Camera:getPosition()
    return mfloor(self.x) + self.shakeX, mfloor(self.y) + self.shakeY
end

function Camera:attach()
    local x, y = self:getPosition()
    love.graphics.push()
    love.graphics.translate(-x, -y)
end

function Camera:detach()
    love.graphics.pop()
end
