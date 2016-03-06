-- https://github.com/kikito/anim8
local anim8 = require 'anim8'
-- https://github.com/rxi/flux
local flux = require "flux"



local b64 = require "b64"
local testLevel = "eJytl8tOVEEQhlt8AmBBFDY4LgzKghFQTPAyeFkaQF2gIoqXaFgZRIhEo2JCIhuMbNRZIBgBb4t5BF7MvzJVoSiqzzk9sPjSc7qL/qtOd1UdqiGEquIQaFIcNnP0vAA2wRce34Ie0AfumnE8Mi9j1dAMWhStZo6ePxv9ZaU/weMYj/08jvAojEb0O8ExRcnMlTLiHwQXwXkwDO6wH7dZj9Yv8LrM/zVcZ5t74Bq4DC7x3FVQicR/HzwEj8Bj8AQ8UDwDU7z+Grxh1sD3xHEdbIFf4DdY5TVtl7WH/F5j/1OZz3lOsf3aAEtmj6V92EpOpcT/Lec5tvbKsZWcmgEvmZmccdac/4uwt25IXHm2klM1g1eHtpnFsPv+fwh760Y3x2VtKVd1Pg+AXkffq0Oypvekd7ri2LdE9ClXT7MuQfWp7Oh7dWjb0d/cp34s/h72TSjn6Ft/xWdPn+pZG7ii9v5n8PRrGedvY5K4vPOvqb3EzvYB0h9mP0fMGXnxk/45tqfafiaiv2zeM9Xlp+CPwdbzSbXmxe/V/8lI/PT+Kxz/XAPY/rcSdu6GHr2zsvG/Czu9oCgbYXdN+QF+RrC2FP9QqPdV0l8PjfWgRvvPqolF5m1dpHr3PPh1cNbsmdJ/YtgcLvFZe3Vo0fxt0f7jMa30Keco1+hbqcz6kod63urTu8vrWbFxQelTXtwCN0I9P0R/VPng6VP+xfpGHqJPd9je8/fsE/lzk32rOPrku9yT47zvCXAkQd8jllcbyuZj8PtvUT6F+j3XTIfsO+PdXdHvztE7CtpBBz979c3zyfqna0pK/F3gJDjFz1SH6Lt/KOG3/f6P9f8iHET9p/i9/l8EiWmu4O+2SPzS/6kH0/911H/Pmjk9T3P9Bxi//f7QmqJrv08GEmPPOn9PP6ap+Q944Ljq"
testBin = b64.decode(testLevel);
tileRawData = love.math.decompress( testBin, "zlib" )
function tileIndex(raw, tileOffset)
  local bz = (tileOffset * 4) - 3 -- 1 based indexing is weird
  local idx = string.byte(raw, bz)
  if idx == nil then return nil end
  idx = idx + (string.byte(raw, bz+1)*256)
  idx = idx + (string.byte(raw, bz+2)*65536)
  idx = idx + (string.byte(raw, bz+3)*16777216)
  return idx
end



local zombieSheet, playerSheet, tilesetImage, Zanim, Panim
local screenWidth, screenHeight
local info = "?"

local smallfont
local zombie = {x=0, y=100, hx=100, hy=100, cx=3, cy=3} -- position, heading, cell
local player = {x=315, y=122, hx=300, hy=100, cx=9, cy=3} -- position, heading, cell
local background = {x = 1, y = 1}
local moving = false -- is player moving?
local buttons = {up={155, 290}, down={155, 430}, left={85, 360}, right={225, 360}, action={900,650}}

local map -- stores tiledata
local mapWidth, mapHeight -- width and height in tiles

local mapX, mapY -- view x,y in tiles. can be a fractional value like 3.25.

local tilesDisplayWidth, tilesDisplayHeight -- number of tiles to show
local zoomX, zoomY

local tilesetImage
local tileSize -- size of tiles in pixels
local tileQuads = {} -- parts of the tileset used for different tiles
local tilesetSprite


function setupMap()
  mapWidth = 32
  mapHeight = 32

  map = {}
  for x=1,mapWidth do
    map[x] = {}
    for y=1,mapHeight do
      map[x][y] = tileIndex(tileRawData, (y*mapWidth)+x)
    end
  end
end

function setupMapView()
  tileSize = 16
  mapX = 1
  mapY = 1
  zoomX = 2
  zoomY = 2

  tilesDisplayWidth = math.ceil(screenWidth / (tileSize*zoomX)) + 3
  tilesDisplayHeight = math.ceil(screenHeight / (tileSize*zoomY)) + 2

end

function setupTileset()
  tilesetImage = love.graphics.newImage("ztown.png")
  tilesetImage:setFilter("nearest", "nearest")

  for x=0, 15 do
    for y=0, 15 do
      tileQuads[(y*16)+x+1] =
        love.graphics.newQuad(
          x * tileSize, y * tileSize,
          tileSize, tileSize, tilesetImage:getWidth(), tilesetImage:getHeight()
        )
    end
  end
  tilesetBatch = love.graphics.newSpriteBatch(tilesetImage, (tilesDisplayWidth * tilesDisplayHeight)) -- will need 2nd set for overlay layer

  updateTilesetBatch()
end

function updateTilesetBatch()
  tilesetBatch:clear()
  mw = math.min(mapWidth, tilesDisplayWidth)
  mh = math.min(mapHeight, tilesDisplayHeight)
  for x=0, mw-1 do
    for y=0, mh-1 do
      toAdd = tileQuads[map[x+math.floor(mapX)][y+math.floor(mapY)]]
      if (toAdd ~= nil) then tilesetBatch:add(toAdd,x*tileSize, y*tileSize) end
    end
  end
  tilesetBatch:flush()
end

-- central function for moving the map by whole tiles
function moveMap(dx, dy)
  --background.x = background.x - (dx * tileSize)
  --background.y = background.y - (dy * tileSize)
  oldMapX = mapX
  oldMapY = mapY
  mapX = math.max(math.min(mapX + dx, mapWidth - tilesDisplayWidth), 1)
  mapY = math.max(math.min(mapY + dy, mapHeight - tilesDisplayHeight), 1)
  if mapX ~= oldMapX then background.x = background.x + (dx * tileSize * zoomX) end
  if mapY ~= oldMapY then background.y = background.y + (dy * tileSize * zoomY) end
  -- only update if we actually moved
  if math.floor(mapX) ~= math.floor(oldMapX) or math.floor(mapY) ~= math.floor(oldMapY) then
    updateTilesetBatch()
  end
end

-- Load non dynamic values
function love.load()
  screenWidth, screenHeight = love.graphics.getDimensions( )
  smallfont = love.graphics.newImageFont("smallfont.png",
    " abcdefghijklmnopqrstuvwxyz" ..
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ0" ..
    "123456789.,!?-+/():;%&`'*#=[]\"")
  zombieSheet = love.graphics.newImage("zombie.png")
  zombieSheet:setFilter("linear", "nearest") -- pixel art scaling: linear down, nearest up

  playerSheet = love.graphics.newImage("player.png")
  playerSheet:setFilter("linear", "nearest")

  local zg = anim8.newGrid(41, 41, zombieSheet:getWidth(), zombieSheet:getHeight(), 7, 22)
  Zanim = anim8.newAnimation(zg('1-2',1), 0.2)

  local pg = anim8.newGrid(26, 37, playerSheet:getWidth(), playerSheet:getHeight(), 430, 253)
  Panim = anim8.newAnimation(pg('1-4',1), 0.1)

  setupMap()
  setupMapView()
  setupTileset()
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
  local dx = 0
  local dy = 0
  if input.up then dy = -1 end
  if input.down then dy = 1 end
  if input.left then dx = -1 end
  if input.right then dx = 1 end

  -- Moving character over static background
  --if (dx ~= 0 or dy ~= 0) then startMove(player, 0.4, dx, dy) end

  -- static character over moving background
  if (dx ~= 0 or dy ~= 0) then
    if moving == true then return end
    startMove(zombie, 0.4, -dx, -dy)
    startMove(background, 0.4, -dx, -dy)
  end

  if input.action then info = "!!!" else info = "?" end
end

function startMove(ch, duration, dx, dy, scale)
  moving = true
  ch.hx = ch.x + (dx * tileSize * zoomX)
  ch.hy = ch.y + (dy * tileSize * zoomY)
  flux.to(ch, duration, {x=ch.hx, y=ch.hy}):ease("linear"):oncomplete(endMove)
end
function endMove(ch)
  ch.cx=ch.x
  ch.cy=ch.y
  moveMap(math.floor(-background.x/(tileSize*zoomX)), math.floor(-background.y/(tileSize*zoomY)))
  moving = false
end

-- Draw a frame
function love.draw()
  love.graphics.setColor(255, 255, 255, 255)
  -- tile batch backdrop
  love.graphics.draw(tilesetBatch,
     math.floor(background.x - zoomX*(mapX%1)*tileSize),
     math.floor(background.y - zoomY*(mapY%1)*tileSize),
    0, zoomX, zoomY)

  love.graphics.setFont(smallfont)
  love.graphics.print("Brains! "..tileIndex(tileRawData, 178), zombie.x + 35, zombie.y - 35)
  love.graphics.print(info, player.x + 35, player.y - 35)

  Zanim:draw(zombieSheet, zombie.x, zombie.y, 0, 2.0) -- rotation, scale
  Panim:draw(playerSheet, player.x, player.y, 0, 2.0)
  --love.graphics.draw(zombSheet,zquad, 30 + (10 * math.cos(fh*4)), 20 + (10 * math.sin(fh*4)))

  --near last, the control outlines
  love.graphics.setColor(0, 0, 0, 200)
  -- directions
  love.graphics.circle("line", buttons.up[1], buttons.up[2], 50, 4)
  love.graphics.circle("line", buttons.down[1], buttons.down[2], 50, 4)
  love.graphics.circle("line", buttons.left[1], buttons.left[2], 50, 4)
  love.graphics.circle("line", buttons.right[1], buttons.right[2], 50, 4)
  -- action
  love.graphics.circle("line", buttons.action[1], buttons.action[2], 50, 6)

  -- FPS counter- always last.
  love.graphics.setColor(255, 128, 0, 200)
  love.graphics.print(background.x..","..background.y.."FPS: "..love.timer.getFPS(), 10, 20)
end
