-- push.lua (fixed for LÖVE 11.x+)
-- Based on v0.4 by Ulysse Ramage (2020)
-- Patched 2025/2026 for love.getDPIScale() instead of getPixelScale()
-- Compatible with love.js and modern desktop/mobile

local love11 = love._version_major == 11  -- more reliable than love.getVersion() == 11

local push = {
  defaults = {
    fullscreen    = false,
    resizable     = false,
    pixelperfect  = false,
    highdpi       = true,
    canvas        = true,
    stencil       = true
  }
}

setmetatable(push, push)

function push:applySettings(settings)
  for k, v in pairs(settings) do
    self["_" .. k] = v
  end
end

function push:resetSettings()
  return self:applySettings(self.defaults)
end

function push:setupScreen(WWIDTH, WHEIGHT, RWIDTH, RHEIGHT, settings)
  settings = settings or {}
  self._WWIDTH  = WWIDTH
  self._WHEIGHT = WHEIGHT
  self._RWIDTH  = RWIDTH
  self._RHEIGHT = RHEIGHT

  self:applySettings(self.defaults)   -- defaults first
  self:applySettings(settings)        -- then custom

  local flags = {
    fullscreen = self._fullscreen,
    resizable  = self._resizable,
    highdpi    = self._highdpi
  }

  love.window.updateMode(self._RWIDTH, self._RHEIGHT, flags)

  self:initValues()

  if self._canvas then
    self:setupCanvas({ "default" })
  end

  self._borderColor = {0, 0, 0}
  self._drawFunctions = {
    ["start"] = self.start,
    ["end"]   = self.finish
  }

  return self
end

function push:setupCanvas(canvases)
  table.insert(canvases, { name = "_render", private = true })
  self._canvas = true
  self.canvases = {}

  for _, c in ipairs(canvases) do
    self:addCanvas(c)
  end

  return self
end

function push:addCanvas(params)
  table.insert(self.canvases, {
    name    = params.name,
    private = params.private,
    shader  = params.shader,
    canvas  = love.graphics.newCanvas(self._WWIDTH, self._WHEIGHT),
    stencil = params.stencil or self._stencil
  })
end

function push:setCanvas(name)
  if not self._canvas then return true end

  local ct = self:getCanvasTable(name)
  if ct then
    love.graphics.setCanvas({ ct.canvas, stencil = ct.stencil })
  end
end

function push:getCanvasTable(name)
  for _, ct in ipairs(self.canvases) do
    if ct.name == name then
      return ct
    end
  end
end

function push:setShader(name, shader)
  if not shader then
    self:getCanvasTable("_render").shader = name
  else
    self:getCanvasTable(name).shader = shader
  end
end

function push:initValues()
  local pscale = 1
  if self._highdpi then
    pscale = love.window.getDPIScale() or 1
  end

  self._PSCALE = pscale

  self._SCALE = {
    x = (self._RWIDTH  / self._WWIDTH)  * self._PSCALE,
    y = (self._RHEIGHT / self._WHEIGHT) * self._PSCALE
  }

  if self._stretched then
    self._OFFSET = { x = 0, y = 0 }
  else
    local uniformScale = math.min(self._SCALE.x, self._SCALE.y)
    if self._pixelperfect then
      uniformScale = math.floor(uniformScale)
    end

    self._OFFSET = {
      x = (self._SCALE.x - uniformScale) * (self._WWIDTH  / 2),
      y = (self._SCALE.y - uniformScale) * (self._WHEIGHT / 2)
    }

    self._SCALE.x = uniformScale
    self._SCALE.y = uniformScale
  end

  self._GWIDTH  = self._RWIDTH  * self._PSCALE - self._OFFSET.x * 2
  self._GHEIGHT = self._RHEIGHT * self._PSCALE - self._OFFSET.y * 2
end

function push:start()
  if self._canvas then
    love.graphics.push()
    love.graphics.origin()
    local ct = self:getCanvasTable("default") or self.canvases[1]
    love.graphics.setCanvas({ ct.canvas, stencil = ct.stencil })
  else
    love.graphics.translate(self._OFFSET.x, self._OFFSET.y)
    love.graphics.setScissor(
      self._OFFSET.x,
      self._OFFSET.y,
      self._WWIDTH  * self._SCALE.x,
      self._WHEIGHT * self._SCALE.y
    )
    love.graphics.push()
    love.graphics.scale(self._SCALE.x, self._SCALE.y)
  end
end

function push:applyShaders(canvas, shaders)
  local oldShader = love.graphics.getShader()
  local oldCanvas = love.graphics.getCanvas()

  if #shaders <= 1 then
    love.graphics.setShader(shaders[1])
    love.graphics.draw(canvas)
  else
    -- Need temp canvas for ping-pong
    local tmp = self:getCanvasTable("_tmp")
    if not tmp then
      self:addCanvas({ name = "_tmp", private = true })
      tmp = self:getCanvasTable("_tmp")
    end

    love.graphics.push()
    love.graphics.origin()

    local input  = canvas
    local output = tmp.canvas

    for i, sh in ipairs(shaders) do
      love.graphics.setCanvas(output)
      love.graphics.clear()
      love.graphics.setShader(sh)
      love.graphics.draw(input)

      input  = output
      output = (output == canvas) and tmp.canvas or canvas
    end

    love.graphics.pop()
    love.graphics.setCanvas(oldCanvas)
    love.graphics.draw(input)
  end

  love.graphics.setShader(oldShader)
end

function push:finish(shader)
  love.graphics.setBackgroundColor(unpack(self._borderColor))

  if self._canvas then
    local renderTable = self:getCanvasTable("_render")
    love.graphics.pop()

    love.graphics.setColor(1, 1, 1)

    -- Composite all non-private canvases → _render
    love.graphics.setCanvas(renderTable.canvas)
    love.graphics.clear()

    for _, ct in ipairs(self.canvases) do
      if not ct.private then
        local sh = ct.shader
        local shList = type(sh) == "table" and sh or { sh }
        self:applyShaders(ct.canvas, shList)
      end
    end

    love.graphics.setCanvas()

    -- Draw final render with offset & scale
    love.graphics.translate(self._OFFSET.x, self._OFFSET.y)
    love.graphics.push()
    love.graphics.scale(self._SCALE.x, self._SCALE.y)

    local finalShader = shader or renderTable.shader
    local finalList = type(finalShader) == "table" and finalShader or { finalShader }
    self:applyShaders(renderTable.canvas, finalList)

    love.graphics.pop()

    -- Clean canvases
    for _, ct in ipairs(self.canvases) do
      love.graphics.setCanvas(ct.canvas)
      love.graphics.clear()
    end
    love.graphics.setCanvas()
    love.graphics.setShader()
  else
    love.graphics.pop()
    love.graphics.setScissor()
  end
end

function push:setBorderColor(r, g, b)
  if g and b then
    self._borderColor = { r, g, b }
  else
    self._borderColor = r  -- assume table
  end
end

function push:toGame(x, y)
  x = x - self._OFFSET.x
  y = y - self._OFFSET.y

  local nx = x / self._GWIDTH
  local ny = y / self._GHEIGHT

  if nx >= 0 and nx <= 1 and ny >= 0 and ny <= 1 then
    return nx * self._WWIDTH, ny * self._WHEIGHT
  end

  return nil, nil
end

function push:resize(w, h)
  if self._highdpi then
    w = w / self._PSCALE
    h = h / self._PSCALE
  end
  self._RWIDTH  = w
  self._RHEIGHT = h
  self:initValues()
end

function push:getWidth()  return self._WWIDTH  end
function push:getHeight() return self._WHEIGHT end
function push:getDimensions() return self._WWIDTH, self._WHEIGHT end

return push