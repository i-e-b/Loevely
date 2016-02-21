-- https://github.com/kikito/anim8
local anim8 = require 'anim8'
-- https://github.com/rxi/flux
local flux = require "flux"

local zombieSheet, playerSheet, Zanim, Panim

local smallfont
local zombie = {x=100, y=100, hx=100, hy=100, cx=3, cy=3} -- position, heading, cell
local player = {x=300, y=100, hx=300, hy=100, cx=9, cy=3} -- position, heading, cell

-- Load non dynamic values
function love.load()
  smallfont = love.graphics.newImageFont("smallfont.png",
    " abcdefghijklmnopqrstuvwxyz" ..
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ0" ..
    "123456789.,!?-+/():;%&`'*#=[]\"")
  zombieSheet = love.graphics.newImage("zombie.png")
  playerSheet = love.graphics.newImage("player.png")
  local zg = anim8.newGrid(41, 41, zombieSheet:getWidth(), zombieSheet:getHeight(), 7, 22)
  Zanim = anim8.newAnimation(zg('1-2',1), 0.2)

  local pg = anim8.newGrid(26, 37, playerSheet:getWidth(), playerSheet:getHeight(), 430, 253)
  Panim = anim8.newAnimation(pg('1-4',1), 0.1)
end

function love.keypressed(k)
	if k == 'escape' then
		love.event.push('quit') -- Quit the game.
	end
end

function updateAnimations(dt)
  flux.update(dt)
  Zanim:update(dt)
  Panim:update(dt)
end

local input = {up=false, down=false, left=false, right=false, action=false}
function readInputs()
  input.up = love.keyboard.isDown("up")
  input.down = love.keyboard.isDown("down")
  input.left = love.keyboard.isDown("left")
  input.right = love.keyboard.isDown("right")
  input.action = love.keyboard.isDown("lctrl")

  -- todo: if press in a special area, that input goes true
  if love.mouse.isDown(1) then
    --zombie.hx, zombie.hy = love.mouse.getPosition()
    --startMove(zombie, 1.4)
	end

  local touches = love.touch.getTouches()
  for i, id in ipairs(touches) do
    --zombie.hx, zombie.hy  = love.touch.getPosition(id)
    --startMove(zombie, 1.4)
    break
  end
end

-- Update, with frame time in fractional seconds
function love.update(dt)
  readInputs()
  updateAnimations(dt)
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
  love.graphics.setFont(smallfont)
  love.graphics.print("Brains!", zombie.x + 35, zombie.y - 35)

  Zanim:draw(zombieSheet, zombie.x, zombie.y, 0, 2.0) -- rotation, scale
  Panim:draw(playerSheet, player.x, player.y, 0, 2.0)
  --love.graphics.draw(zombSheet,zquad, 30 + (10 * math.cos(fh*4)), 20 + (10 * math.sin(fh*4)))
end
