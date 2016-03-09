-- character animations
local anim8 = require 'anim8'
-- movement tweening. Modified from standard
local flux = require "flux"
local level = require "level"

local screenWidth, screenHeight, playerCentreX, playerCentreY

local smallfont
 -- todo: load positions from level
local zombie = {speed=2, x=16, y=20, thinking="Brains!", anims={}}
local player = {speed=4, x=16, y=10, thinking="", anims={}}
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

  local creepSheet = love.graphics.newImage("creeps.png")
  creepSheet:setFilter("linear", "nearest") -- pixel art scaling: linear down, nearest up

  zombie.sheet = creepSheet
  player.sheet = creepSheet
  local sw = creepSheet:getWidth()
  local sh = creepSheet:getHeight()

  local grid = anim8.newGrid(17, 18, sw, sh, 0, 0)
  zombie.anims['down'] = anim8.newAnimation(grid('9-12',1), 0.2)
  zombie.anims['right'] = anim8.newAnimation(grid('9-12',2), 0.2)
  zombie.anims['left'] = anim8.newAnimation(grid('9-12',3), 0.2)
  zombie.anims['up'] = anim8.newAnimation(grid('9-12',4), 0.2)
  zombie.anims['stand'] = anim8.newAnimation(grid(7,'1-4'), 0.4)
  zombie.anim = zombie.anims['stand']

  player.anims['down'] = anim8.newAnimation(grid('1-4',1), 0.1)
  player.anims['right'] = anim8.newAnimation(grid('1-4',2), 0.1)
  player.anims['left'] = anim8.newAnimation(grid('1-4',3), 0.1)
  player.anims['up'] = anim8.newAnimation(grid('1-4',4), 0.1)
  player.anims['stand'] = anim8.newAnimation(grid(6,'1-3'), 0.8)
  player.anim = player.anims['stand']
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
  local tilePixelSize = currentLevel.zoom * currentLevel.tiles.size
  local targetX = playerCentreX - (player.x * tilePixelSize)
  local targetY = playerCentreY - ((player.y+0.7) * tilePixelSize)

  -- adjust display grid and mapOffset
  level.moveMap(currentLevel, targetX, targetY, mapOffset)
end

function updateControl()
  local dx = 0
  local dy = 0
      if input.up    then dy = -1; dx = 0
  elseif input.down  then dy =  1; dx = 0
  elseif input.left  then dx = -1; dy = 0
  elseif input.right then dx =  1; dy = 0 end

  if input.action then player.thinking = "!!!" else player.thinking = "" end

  -- static character over moving background
  if not moving and (dx ~= 0 or dy ~= 0) then
    if (level.isPassable(currentLevel, player, dx, dy)) then
      startMove(player, 1/player.speed, dx, dy)
    else
      dx =  0; dy = 0
    end
  end
end

function startMove(ch, duration, dx, dy, scale)
  -- lock out player movement
  moving = true

  -- set directional animation
  if (dx == 1) then ch.anim = ch.anims['right']
  elseif (dx == -1) then ch.anim = ch.anims['left']
  elseif (dy == 1) then ch.anim = ch.anims['down']
  elseif (dy == -1) then ch.anim = ch.anims['up'] end

  -- move to next tile
  flux.to(ch, duration, {x=ch.x+dx, y=ch.y+dy }):ease("linear"):oncomplete(endMove)
end
function endMove(ch)
  -- return to idle animation
  player.anim = player.anims['stand']
  -- unlock movement
  moving = false
end

-- Draw a frame
function love.draw()

  love.graphics.setColor(255, 255, 255, 255)
  love.graphics.setFont(smallfont)
  local zts = currentLevel.zoom * currentLevel.tiles.size
  local zoom = currentLevel.zoom
  local sceneX = mapOffset.x - zts * currentLevel.mapX
  local sceneY = mapOffset.y - zts * currentLevel.mapY

  -- assign all the active chars to a draw row, then pick them back out
  -- as we draw
  local charRows = {}
  appendMap(charRows, zombie, level.posToRow(zombie, currentLevel))
  appendMap(charRows, player, level.posToRow(player, currentLevel))

  -- todo: scan through rows, draw chars on or above the row
  --       then the fg row.
  for row = 1, currentLevel.rowsToDraw do
    level.drawBgRow(row, currentLevel, mapOffset)
    -- pick chars in slots
    if (charRows[row]) then
      for i,char in ipairs(charRows[row]) do
        love.graphics.print(char.thinking, math.floor(sceneX + (char.x*zts)), math.floor(sceneY + (char.y+0.4)*zts))
        char.anim:draw(char.sheet, sceneX + (char.x*zts), sceneY + ((char.y+0.8)*zts), 0, zoom)
      end
    end
    level.drawFgRow(row, currentLevel, mapOffset)
  end

  -- be nice to the gc, assuming it does fast gen 0
  charRows = nil

  drawControlHints()  --near last, the control outlines
  drawFPS()  -- FPS counter- always last.
end

function appendMap(arry, obj, index)
  if not arry[index] then
    arry[index] = {obj}
    return
  end
  table.insert(arry[index], obj)
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
