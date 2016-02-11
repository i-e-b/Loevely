--https://github.com/kikito/anim8
local anim8 = require 'anim8'


local zombieSheet, Zanim, px, py, dx, dy

-- Load some default values for our rectangle.
function love.load()
  fh = 0
  zombieSheet = love.graphics.newImage("zombie.png");
  local g = anim8.newGrid(41, 41, zombieSheet:getWidth(), zombieSheet:getHeight(), 7, 22)
  Zanim = anim8.newAnimation(g('1-2',1), 0.1)
  --zquad = love.graphics.newQuad(7, 22, 41, 41, zombSheet:getDimensions())
  dx = 0
  dy = 0
  px = 100
  py = 100
end

-- Increase the size of the rectangle every frame.
function love.update(dt)
  dx = 0
  dy = 0
  if love.keyboard.isDown("h") then dy = -dt end
  if love.keyboard.isDown("i") then dy = dt end
  if love.keyboard.isDown("l") then dx = -dt end
  if love.keyboard.isDown("o") then dx = dt end
  Zanim:update(dt)
  px = px + (dx * 100)
  py = py + (dy * 100)
end


-- Draw a frame
function love.draw()
  love.graphics.print("Brains!", px + 35, py - 35)

  Zanim:draw(zombieSheet, px, py)
  --love.graphics.draw(zombSheet,zquad, 30 + (10 * math.cos(fh*4)), 20 + (10 * math.sin(fh*4)))
end
