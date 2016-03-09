-- character animations
local anim8 = require 'anim8'
-- movement tweening. Modified from standard
local flux = require "flux"
local level = require "level"

local screenWidth, screenHeight, playerCentreX, playerCentreY
local info = "?"

local smallfont
local zombie = {x=16, y=20} -- todo: load positions from level
local player = {x=16, y=10} -- tile position, but can be fractional
local mapOffset = {x = 1, y = 1} -- pixel offset for scrolling
local moving = false -- is player moving? (if so, direction won't change until finished)
-- Position of touch buttons:
local buttons = {up={155, 290}, down={155, 430}, left={85, 360}, right={225, 360}, action={900,650}}
-- currently loaded level data
local currentLevel

-- Load non dynamic values
function love.load()
  screenWidth, screenHeight = love.graphics.getDimensions( )
  currentLevel = level.load("ztown.tmx", screenWidth, screenHeight);

  playerCentreX = (screenWidth / 2) - (currentLevel.tiles.size / 2)
  playerCentreY = (screenHeight / 2) - (currentLevel.tiles.size / 2)

  smallfont = love.graphics.newImageFont("smallfont.png", " abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,!?-+/():;%&`'*#=[]\"")
  zombie.sheet = love.graphics.newImage("zombie.png")
  zombie.sheet:setFilter("linear", "nearest") -- pixel art scaling: linear down, nearest up

  player.sheet = love.graphics.newImage("player.png")
  player.sheet:setFilter("linear", "nearest")

  local zg = anim8.newGrid(41, 41, zombie.sheet:getWidth(), zombie.sheet:getHeight(), 7, 22)
  zombie.anim = anim8.newAnimation(zg('1-2',1), 0.2)

  local pg = anim8.newGrid(26, 37, player.sheet:getWidth(), player.sheet:getHeight(), 430, 253)
  player.anim = anim8.newAnimation(pg('1-4',1), 0.1)
end

function love.keypressed(k)
	if k == 'escape' then
		love.event.push('quit') -- Quit the game.
	--elseif k == 'backspace' then
  --  debug.debug() -- need to be attached to a console, or this freezes everything.
  end
end

function updateAnimations(dt)
  flux.update(dt)
  zombie.anim:update(dt)
  player.anim:update(dt)
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

  -- centre map around player
  local tilePixelSize = currentLevel.zoomX * currentLevel.tiles.size
  local targetX = playerCentreX - (player.x * tilePixelSize)
  local targetY = playerCentreY - (player.y * tilePixelSize)

  -- adjust display grid and mapOffset
  level.moveMap(currentLevel, targetX, targetY, mapOffset)
end

function updateControl()
  local dx = 0
  local dy = 0
      if input.up    then dy = -1
  elseif input.down  then dy =  1
  elseif input.left  then dx = -1
  elseif input.right then dx =  1 end

  if input.action then info = "!!!" else info = "?" end

  -- static character over moving background
  if not moving and (dx ~= 0 or dy ~= 0) then
    if (level.isPassable(currentLevel, player.x+dx, player.y+dy)) then
      startMove(player, 0.4, dx, dy)
    end
  end
end

function startMove(ch, duration, dx, dy, scale)
  moving = true
  flux.to(ch, duration, {x=ch.x+dx, y=ch.y+dy }):ease("linear"):oncomplete(endMove)
end
function endMove(ch)
  moving = false
end

-- Draw a frame
function love.draw()

  love.graphics.setColor(255, 255, 255, 255)
  love.graphics.setFont(smallfont)
  local zts = currentLevel.zoomX * currentLevel.tiles.size
  local zoomX = currentLevel.zoomX
  local zoomY = currentLevel.zoomY
  local sceneX = mapOffset.x - zoomX * currentLevel.mapX * currentLevel.tiles.size
  local sceneY = mapOffset.y - zoomY * currentLevel.mapY * currentLevel.tiles.size

  -- assign all the active chars to a draw row, then pick them back out
  -- as we draw
  local charRows = {}
  charRows[level.posToRow(zombie, currentLevel)] = {zombie}
  charRows[level.posToRow(player, currentLevel)] = {player}

  -- todo: scan through rows, draw chars on or above the row
  --       then the fg row.
  for row = 1, currentLevel.rowsToDraw do
    level.drawBgRow(row, currentLevel, mapOffset)
    -- pick chars in slots
    if (charRows[row]) then
      for i,char in ipairs(charRows[row]) do
        char.anim:draw(char.sheet, sceneX + (char.x*zts), sceneY + (char.y*zts), 0, zoomX)
      end
    end
      --zombie.anim:draw(zombie.sheet, sceneX + (zombie.x*zts), sceneY + (zombie.y*zts), 0, zoomX) -- rotation, scale
      --player.anim:draw(player.sheet, sceneX + (player.x*zts), sceneY + (player.y*zts), 0, zoomX)
    level.drawFgRow(row, currentLevel, mapOffset)
  end

  -- be nice to the gc, assuming it does fast gen 0
  charRows = nil

  -- speech over fg stuff
  love.graphics.print("Brains! ", sceneX + zombie.x + 35, sceneY + zombie.y - 35)
  love.graphics.print(info, playerCentreX + 35, playerCentreY - 35)
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
