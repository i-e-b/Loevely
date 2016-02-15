-- https://github.com/kikito/anim8
local anim8 = require 'anim8'
-- https://github.com/rxi/flux
local flux = require "flux"

local zombieSheet, Zanim, px, py, dx, dy
local swidth, sheight

local zombie = {x=100, y=100, hx=100, hy=100, cx=100, cy=100} -- position, heading, cell

-- Load non dynamic values
function love.load()
  fh = 0
  zombieSheet = love.graphics.newImage("zombie.png");
  local g = anim8.newGrid(41, 41, zombieSheet:getWidth(), zombieSheet:getHeight(), 7, 22)
  Zanim = anim8.newAnimation(g('1-2',1), 0.4)
  --zquad = love.graphics.newQuad(7, 22, 41, 41, zombSheet:getDimensions())
  dx = 0
  dy = 0
  swidth, sheight = love.graphics.getDimensions()
end

function love.keypressed(k)
	if k == 'escape' then
		love.event.push('quit') -- Quit the game.
	end
end

-- Update, with frame time in fractional seconds
function love.update(dt)
  flux.update(dt)
  dx = 0
  dy = 0
  if love.keyboard.isDown("up") then dy = -dt end
  if love.keyboard.isDown("down") then dy = dt end
  if love.keyboard.isDown("left") then dx = -dt end
  if love.keyboard.isDown("right") then dx = dt end
  Zanim:update(dt)
  zombie.x = zombie.x + (dx * 100)
  zombie.y = zombie.y + (dy * 100)

  if love.mouse.isDown(1) then
    zombie.hx, zombie.hy = love.mouse.getPosition()
    startMove(zombie, 1.4)
	end

  local touches = love.touch.getTouches()
  for i, id in ipairs(touches) do
    zombie.hx, zombie.hy  = love.touch.getPosition(id)
    startMove(zombie, 1.4)
    break
  end
end

function startMove(ch, dt)
  flux.to(ch, dt, {x=ch.hx, y=ch.hy}):ease("linear"):oncomplete(endMove)
end
function endMove(ch)
  ch.cx=ch.x
  ch.cy=ch.y
end

-- Draw a frame
function love.draw()
  love.graphics.print("Brains! "..zombie.cx..", "..zombie.cy, zombie.x + 35, zombie.y - 35)

  Zanim:draw(zombieSheet, zombie.x, zombie.y, 0, 2.0) -- rotation, scale
  --love.graphics.draw(zombSheet,zquad, 30 + (10 * math.cos(fh*4)), 20 + (10 * math.sin(fh*4)))
end
