-- https://github.com/kikito/anim8
local anim8 = require 'anim8'
-- https://github.com/rxi/flux
local flux = require "flux"
local level = require "level"


local zombieSheet, playerSheet, Zanim, Panim
local screenWidth, screenHeight
local info = "?"

local smallfont
local zombie = {x=0, y=100, hx=100, hy=100, cx=3, cy=3} -- position, heading, cell
local player = {x=315, y=122, hx=300, hy=100, cx=9, cy=3} -- position, heading, cell
local background = {x = 1, y = 1}
local moving = false -- is player moving?
local buttons = {up={155, 290}, down={155, 430}, left={85, 360}, right={225, 360}, action={900,650}}
local currentLevel

-- Load non dynamic values
function love.load()
  screenWidth, screenHeight = love.graphics.getDimensions( )

  currentLevel = level.load("hospital.tmx", screenWidth, screenHeight);
  smallfont = love.graphics.newImageFont("smallfont.png", " abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,!?-+/():;%&`'*#=[]\"")
  zombieSheet = love.graphics.newImage("zombie.png")
  zombieSheet:setFilter("linear", "nearest") -- pixel art scaling: linear down, nearest up

  playerSheet = love.graphics.newImage("player.png")
  playerSheet:setFilter("linear", "nearest")

  local zg = anim8.newGrid(41, 41, zombieSheet:getWidth(), zombieSheet:getHeight(), 7, 22)
  Zanim = anim8.newAnimation(zg('1-2',1), 0.2)

  local pg = anim8.newGrid(26, 37, playerSheet:getWidth(), playerSheet:getHeight(), 430, 253)
  Panim = anim8.newAnimation(pg('1-4',1), 0.1)
end

function love.keypressed(k)
	if k == 'escape' then
		love.event.push('quit') -- Quit the game.
	elseif k == 'backspace' then
    debug.debug()
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
  local dx = 0
  local dy = 0
      if input.up    then dy = -1
  elseif input.down  then dy =  1
  elseif input.left  then dx = -1
  elseif input.right then dx =  1 end

  if input.action then info = "!!!" else info = "?" end
  -- Moving character over static background
  --if (dx ~= 0 or dy ~= 0) then startMove(player, 0.4, dx, dy) end

  -- static character over moving background
  if not moving and (dx ~= 0 or dy ~= 0) then
    startMove(background, 0.4, -dx, -dy)
  end
end

function startMove(ch, duration, dx, dy, scale)
  moving = true
  ch.hx = ch.x + (dx * currentLevel.tiles.size * currentLevel.zoomX)
  ch.hy = ch.y + (dy * currentLevel.tiles.size * currentLevel.zoomY)
  flux.to(ch, duration, {x=ch.hx, y=ch.hy}):ease("linear"):oncomplete(endMove)
end
function endMove(ch)
  ch.cx=ch.x
  ch.cy=ch.y
  level.moveMap(currentLevel,
      math.floor(-background.x/(currentLevel.tiles.size*currentLevel.zoomX)),
      math.floor(-background.y/(currentLevel.tiles.size*currentLevel.zoomY)),
      background)
  moving = false
end

-- Draw a frame
function love.draw()
  love.graphics.setColor(255, 255, 255, 255)
  love.graphics.setFont(smallfont)
  local zoomX = currentLevel.zoomX
  local zoomY = currentLevel.zoomY
  local sceneX = background.x - zoomX * currentLevel.mapX * currentLevel.tiles.size
  local sceneY = background.y - zoomY * currentLevel.mapY * currentLevel.tiles.size
  level.drawBg(currentLevel, background)

  love.graphics.print("Brains! ", sceneX + zombie.x + 35, sceneY + zombie.y - 35)
  love.graphics.print(info, player.x + 35, player.y - 35)

  Zanim:draw(zombieSheet, sceneX + zombie.x, sceneY + zombie.y, 0, zoomX) -- rotation, scale
  Panim:draw(playerSheet, player.x, player.y, 0, zoomX)

  level.drawFg(currentLevel, background)
  drawControlHints()  --near last, the control outlines
  drawFPS()  -- FPS counter- always last.
end

function drawFPS()
  love.graphics.setColor(255, 128, 0, 255)
  love.graphics.print("FPS: ", 10, 20)
  love.graphics.print(love.timer.getFPS(), 44, 20)
end

function drawControlHints()
  for itr = 0, 2 do
    love.graphics.setColor(itr*70, itr*70, itr*70, 200)
    -- directions
    love.graphics.circle("line", buttons.up[1] + itr, buttons.up[2], 50, 4)
    love.graphics.circle("line", buttons.down[1] + itr, buttons.down[2], 50, 4)
    love.graphics.circle("line", buttons.left[1] + itr, buttons.left[2], 50, 4)
    love.graphics.circle("line", buttons.right[1] + itr, buttons.right[2], 50, 4)
    -- action
    love.graphics.circle("line", buttons.action[1] + itr, buttons.action[2], 50, 6)
  end
end
