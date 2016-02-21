-- https://github.com/kikito/anim8
local anim8 = require 'anim8'
-- https://github.com/rxi/flux
local flux = require "flux"

local zombieSheet, playerSheet, Zanim, Panim

local info = "?"

local smallfont
local zombie = {x=0, y=100, hx=100, hy=100, cx=3, cy=3} -- position, heading, cell
local player = {x=300, y=100, hx=300, hy=100, cx=9, cy=3} -- position, heading, cell
local moving = false -- is player moving?
local buttons = {up={155, 290}, down={155, 430}, left={85, 360}, right={225, 360}, action={900,650}}

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

  -- if press in a special area, that input goes true
  if love.mouse.isDown(1) then
    triggerClick(love.mouse.getPosition())
	end

  local touches = love.touch.getTouches()
  for i, id in ipairs(touches) do
    triggerClick(love.touch.getPosition(id))
  end
end
function inButton(x,y,b)
  if (math.abs(x - b[1]) < 50 and math.abs(y - b[2]) < 50)
  then return true else return false end
end
function triggerClick(x,y)
  if inButton(x,y,buttons.up) then input.up = true end
  if inButton(x,y,buttons.down) then input.down = true end
  if inButton(x,y,buttons.left) then input.left = true end
  if inButton(x,y,buttons.right) then input.right = true end
  if inButton(x,y,buttons.action) then input.action = true end
end

-- Update, with frame time in fractional seconds
function love.update(dt)
  readInputs()
  updateAnimations(dt)
  updateControl()
end

function updateControl()
  if input.up then startMove(player, 0.4, 0, -1) end
  if input.down then startMove(player, 0.4, 0, 1) end
  if input.left then startMove(player, 0.4, -1, 0) end
  if input.right then startMove(player, 0.4, 1, 0) end

  if input.action then info = "!!!" else info = "?" end
end

function startMove(ch, duration, dx, dy)
  if moving == true then return end
  ch.hx = ch.x + (dx * 40)
  ch.hy = ch.y + (dy * 40)
  moving = true
  flux.to(ch, duration, {x=ch.hx, y=ch.hy}):ease("linear"):oncomplete(endMove)
end
function endMove(ch)
  moving = false
  ch.cx=ch.x
  ch.cy=ch.y
end

-- Draw a frame
function love.draw()
  love.graphics.setColor(255, 255, 255, 255)
  love.graphics.setFont(smallfont)
  love.graphics.print("Brains!", zombie.x + 35, zombie.y - 35)
  love.graphics.print(info, player.x + 35, player.y - 35)

  Zanim:draw(zombieSheet, zombie.x, zombie.y, 0, 2.0) -- rotation, scale
  Panim:draw(playerSheet, player.x, player.y, 0, 2.0)
  --love.graphics.draw(zombSheet,zquad, 30 + (10 * math.cos(fh*4)), 20 + (10 * math.sin(fh*4)))

  --always last, the control outlines
  love.graphics.setColor(255, 128, 0, 200)
  -- directions
  love.graphics.circle("line", buttons.up[1], buttons.up[2], 50, 4)
  love.graphics.circle("line", buttons.down[1], buttons.down[2], 50, 4)
  love.graphics.circle("line", buttons.left[1], buttons.left[2], 50, 4)
  love.graphics.circle("line", buttons.right[1], buttons.right[2], 50, 4)
  -- action
  love.graphics.circle("line", buttons.action[1], buttons.action[2], 50, 6)
end
