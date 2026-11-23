--[[
    Inflate - Entity
    Base class for things that move and think: the ball, enemies.
    Position is the top-left of the collision box. Behaviour lives in states.
]]

Entity = Class{}

function Entity:init(def)
    self.x = def.x
    self.y = def.y
    self.width = def.width
    self.height = def.height
    self.dx = 0
    self.dy = 0
    self.stateMachine = nil      -- set by the subclass
end

function Entity:changeState(name, params)
    self.stateMachine:change(name, params)
end

function Entity:update(dt)
    self.stateMachine:update(dt)
end

function Entity:centerX() return self.x + self.width / 2 end
function Entity:centerY() return self.y + self.height / 2 end
function Entity:bottom()  return self.y + self.height end

function Entity:collides(other)
    return aabb(self.x, self.y, self.width, self.height,
                other.x, other.y, other.width, other.height)
end
