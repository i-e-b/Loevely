-- https://github.com/kikito/anim8
local anim8 = require 'anim8'
-- https://github.com/rxi/flux
local flux = require "flux"

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
  mapWidth = 60
  mapHeight = 40

  map = {}
  for x=1,mapWidth do
    map[x] = {}
    for y=1,mapHeight do
      map[x][y] = love.math.random(0,3)
    end
  end
end

function setupMapView()
  tileSize = 32
  mapX = 1
  mapY = 1
  tilesDisplayWidth = math.ceil(screenWidth / tileSize) + 3
  tilesDisplayHeight = math.ceil(screenHeight / tileSize) + 2

  zoomX = 1
  zoomY = 1
end

function setupTileset()
  tilesetImage = love.graphics.newImage( "tileset.png" )
  tilesetImage:setFilter("nearest", "linear") -- this "linear filter" removes some artifacts if we were to scale the tiles

  tileQuads[0] = love.graphics.newQuad(5 * tileSize, 18 * tileSize, tileSize, tileSize, tilesetImage:getWidth(), tilesetImage:getHeight())
  tileQuads[1] = love.graphics.newQuad(5 * tileSize, 19 * tileSize, tileSize, tileSize, tilesetImage:getWidth(), tilesetImage:getHeight())
  tileQuads[2] = love.graphics.newQuad(6 * tileSize, 18 * tileSize, tileSize, tileSize, tilesetImage:getWidth(), tilesetImage:getHeight())
  tileQuads[3] = love.graphics.newQuad(6 * tileSize, 19 * tileSize, tileSize, tileSize, tilesetImage:getWidth(), tilesetImage:getHeight())

  tilesetBatch = love.graphics.newSpriteBatch(tilesetImage, tilesDisplayWidth * tilesDisplayHeight)

  updateTilesetBatch()
end

function updateTilesetBatch()
  tilesetBatch:clear()
  for x=0, tilesDisplayWidth-1 do
    for y=0, tilesDisplayHeight-1 do
      tilesetBatch:add(tileQuads[map[x+math.floor(mapX)][y+math.floor(mapY)]],
        x*tileSize, y*tileSize)
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
  if mapX ~= oldMapX then background.x = background.x + (dx * tileSize) end
  if mapY ~= oldMapY then background.y = background.y + (dy * tileSize) end
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
  ch.hx = ch.x + (dx * tileSize)
  ch.hy = ch.y + (dy * tileSize)
  moving = true
  flux.to(ch, duration, {x=ch.hx, y=ch.hy}):ease("linear"):oncomplete(endMove)
end
function endMove(ch)
  moving = false
  ch.cx=ch.x
  ch.cy=ch.y

  moveMap(math.floor(-background.x/tileSize), math.floor(-background.y/tileSize))
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
  love.graphics.print("Brains!", zombie.x + 35, zombie.y - 35)
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
  love.graphics.print("FPS: "..love.timer.getFPS(), 10, 20)
end
