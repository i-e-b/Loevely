local anim8 = require "anim8" -- character animations
local flux = require "flux"   -- movement tweening. Modified from standard
local level = require "level"

local dumper = require "dumper"

local screenWidth, screenHeight, playerCentreX, playerCentreY

local GameScore = 0

local creepSheet -- image that has all character frames
local smallfont  -- in game image font
 -- todo: load positions from level
local zombies = {}
local survivors = {}

local protoZombie = {anims={}}
local protoSurvivor = {anims={}}

local player =
  { -- NPCs follow the same structure
    speed=4, x=16, y=10,  -- tile grid coords
    thinking="",          -- text above the character
    anims={},             -- animation sets against the 'creeps' image
    anim=nil,             -- current stance animation
    moving = false,       -- is player moving between tiles?
    warping = false,      -- is player roving around the sewers?
    followedBy = nil,     -- next element in survivor chain
  --waiting = false       -- should skip the next follow turn (survivors)
  --panic = 0             -- how many rounds of panic left (survivors)
  --locked = false        -- character is locked into an animation, don't interact
  }

local mapOffset = {x = 1, y = 1} -- pixel offset for scrolling

-- Position of touch buttons:
local buttons = {up={155, 290}, down={155, 430}, left={85, 360}, right={225, 360}, action={900,650}}
-- currently loaded level data
local currentLevel

-- Load non dynamic values
function love.load()
  screenWidth, screenHeight = love.graphics.getDimensions( )
  currentLevel = level.load("ztown.tmx", screenWidth, screenHeight);

  playerCentreX = (screenWidth / 2) - (currentLevel.zoom * currentLevel.tiles.size / 2)
  playerCentreY = (screenHeight / 2) - (currentLevel.zoom * currentLevel.tiles.size / 2)

  smallfont = love.graphics.newImageFont("smallfont.png", " abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,!?-+/():;%&`'*#=[]\"")

  creepSheet = love.graphics.newImage("creeps.png")
  creepSheet:setFilter("linear", "nearest") -- pixel art scaling: linear down, nearest up
  local sw = creepSheet:getWidth()
  local sh = creepSheet:getHeight()

  local grid = anim8.newGrid(17, 18, sw, sh, 0, 0)
  protoZombie.anims['down'] = anim8.newAnimation(grid('9-12',1), 0.2)
  protoZombie.anims['right'] = anim8.newAnimation(grid('9-12',2), 0.2)
  protoZombie.anims['left'] = anim8.newAnimation(grid('9-12',3), 0.2)
  protoZombie.anims['up'] = anim8.newAnimation(grid('9-12',4), 0.2)
  protoZombie.anims['stand'] = anim8.newAnimation(grid(7,'1-4'), 0.7)

  player.anims['down'] = anim8.newAnimation(grid('1-4',1), 0.1)
  player.anims['right'] = anim8.newAnimation(grid('1-4',2), 0.1)
  player.anims['left'] = anim8.newAnimation(grid('1-4',3), 0.1)
  player.anims['up'] = anim8.newAnimation(grid('1-4',4), 0.1)
  player.anims['stand'] = anim8.newAnimation(grid(6,'1-3', 6,1, 6,4), {0.8,0.4,0.4,0.7,0.2})
  player.anim = player.anims['stand']

  protoSurvivor.anims['down'] = anim8.newAnimation(grid('1-4',6), 0.1)
  protoSurvivor.anims['right'] = anim8.newAnimation(grid('1-4',7), 0.1)
  protoSurvivor.anims['left'] = anim8.newAnimation(grid('1-4',8), 0.1)
  protoSurvivor.anims['up'] = anim8.newAnimation(grid('1-4',9), 0.1)
  protoSurvivor.anims['help'] = anim8.newAnimation(grid(6,'6-9'), 0.4)
  protoSurvivor.anims['stand'] = anim8.newAnimation(grid(6,'6-7'), 1)

  for i,creep in ipairs(currentLevel.placement) do
    if creep.type == 255 then -- player
      player.x = creep.x; player.y = creep.y
    elseif creep.type == 254 then -- zombie
      table.insert(zombies, makeZombie(creep.x, creep.y))
    elseif creep.type == 256 then -- survivor
      table.insert(survivors, makeSurvivor(creep.x, creep.y))
    end
  end
end

function makeZombie(x,y)
  local newAnims = {}
  for k,anim in pairs(protoZombie.anims) do
    newAnims[k] = anim:clone()
  end
  local z = {speed=2, x=x+1, y=y, thinking="Brains", anims=newAnims}
  z.anim = newAnims['stand']
  return z
end

function makeSurvivor(x,y, name)
  local newAnims = {}
  for k,anim in pairs(protoSurvivor.anims) do
    newAnims[k] = anim:clone()
  end
  local s = {speed=4, score=100, x=x+1, y=y, thinking="Help!", anims=newAnims, panic = 0}
  s.anim = newAnims['help']

  s.color = {
    r = love.math.random(70,255),
    g = love.math.random(70,255),
    b = love.math.random(70,255),
  }

  return s
end

function love.keypressed(k)
	if k == 'escape' then
		love.event.push('quit') -- Quit the game.
  end
end

function updateAnimations(dt)
  flux.update(dt)
  for i,char in ipairs(zombies)   do char.anim:update(dt) end
  for i,char in ipairs(survivors) do char.anim:update(dt) end
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
  -- first, look for impacts that have been drawn already
  updateSurvivors()

  readInputs()
  updateAnimations(dt)
  updateControl()

  -- centre map around player
  local tilePixelSize = currentLevel.zoom * currentLevel.tiles.size
  playerCentreX = (screenWidth / 2) - (tilePixelSize / 2)
  playerCentreY = (screenHeight / 2) - (tilePixelSize / 2)
  local targetX = playerCentreX - (player.x * tilePixelSize)
  local targetY = playerCentreY - ((player.y+0.7) * tilePixelSize)

  -- adjust display grid and mapOffset
  level.moveMap(currentLevel, targetX, targetY, mapOffset)
end

function inSafeHouse(chr)
  for i,sh in ipairs(currentLevel.safeHouses) do
    if sameTile(chr, sh) then -- unhook the chain
      return sh
    end
  end
  return nil
end

function updateSurvivors()
    for i, surv in ipairs(survivors) do
      local safe = inSafeHouse(surv)
      if safe then
        GameScore = GameScore + surv.score
        table.remove(survivors, i)
        if (surv.followedBy) then
          startMoveChain(safe)
          safe.followedBy = surv.followedBy
        end
      elseif (surv.panic > 0) and (not surv.flux) then -- run away!
        surv.thinking = "A"..(string.rep('a',surv.panic)).."!"

        local dx=0
        local dy=0
        while (dx == 0) and (dy == 0) do
          dx = love.math.random( 1, 3 ) - 2
          dy = love.math.random( 1, 3 ) - 2
        end

        if level.isPassable(currentLevel, surv, dx, dy) then
          startMove(surv, 1/surv.speed, dx, dy)
        else
          startMove(surv, 1/surv.speed, 0, 0) -- not sure why this would happen?
        end
      end
    end
end

function sameTile(chr1, chr2, c1dx, c1dy)
  local dx = c1dx or 0
  local dy = c1dy or 0
  return (near(chr1.x + dx) == near(chr2.x)) and (near(chr1.y + dy) == near(chr2.y))
end

function updateControl()
  local dx = 0
  local dy = 0
      if input.up    then dy = -1; dx = 0
  elseif input.down  then dy =  1; dx = 0
  elseif input.left  then dx = -1; dy = 0
  elseif input.right then dx =  1; dy = 0 end

  --[[if input.action and currentLevel.zoom < 20 then
    currentLevel.zoom = currentLevel.zoom + 0.1
  else
    currentLevel.zoom = 4
  end]]

  if input.action and (not warping) then
    -- test for a warp. If so, follow it.
    startWarp()
  elseif not input.action then
    player.thinking = ""
    warping = false -- lock out the warp until the control is lifted
  end

  -- check for obstructions, and start the move animation
  if not moving and (dx ~= 0 or dy ~= 0) then
    if (player.followedBy and sameTile(player, player.followedBy, dx, dy)) then
      -- trying to push back against the chain, panic them rather than blocking
      bustChain(player)
    end
    if (level.isPassable(currentLevel, player, dx, dy)) then
      moving = true
      startMove(player, 1/player.speed, dx, dy)
    else
      dx =  0; dy = 0
    end
  end
end

function near(a) return math.floor(a+0.5) end -- crap, but will do for map indexes

function startWarp()
  player.thinking = "Nothing here"
  local w = currentLevel.warps[near(player.x)]
  if w then
    local loc = w[near(player.y)]
    if loc then
      bustChain(player) -- survivors won't follow you into the dark
      player.thinking = ""
      warping = true -- lock out the warp until the control is lifted
      if player.flux then player.flux:stop() end
      moving = false
      player.anim = player.anims['stand']
      player.x = loc.x; player.y = loc.y
      return
    end
  end
end

function startMove(ch, duration, dx, dy)
  -- reset character movement
  if ch.flux then ch.flux:stop() end

  -- set directional animation
  if (dx == 1) then ch.anim = ch.anims['right']
  elseif (dx == -1) then ch.anim = ch.anims['left']
  elseif (dy == 1) then ch.anim = ch.anims['down']
  elseif (dy == -1) then ch.anim = ch.anims['up'] end

  -- move to next tile
  ch.flux = flux.to(ch, duration, {x=ch.x+dx, y=ch.y+dy })
      :ease("linear"):oncomplete(endMove)

  -- update the chain
  startMoveChain(ch, duration)
end
function endMove(ch)
  -- return to idle animation
  ch.anim = ch.anims['stand']
  ch.flux = nil

  -- reduce panic (survivors)
  if (ch.panic and ch.panic > 0) then
    ch.panic = ch.panic - 1
    if (ch.panic < 1) then ch.thinking = "Help!"; ch.anim = ch.anims['help'] end
  end

  if (ch == player) then
    survivorPickupDetect()
    local house = inSafeHouse(player)
    if house then escapeSurvivors(player, house) end
    moving = false  -- unlock movement
  end
end

function startMoveChain(ch, duration)
  if (ch and ch.followedBy) then
    duration = duration or (1/ch.speed)
    if (ch.followedBy.wait) then
      ch.followedBy.wait = false
    else
      startMove(ch.followedBy, duration, -- always the same speed as leader
        ch.x - ch.followedBy.x,
        ch.y - ch.followedBy.y
      )
    end
  end
end

function escapeSurvivors(leader, house)
  lockAndScoreChain(leader.followedBy, 100)
  house.followedBy = leader.followedBy
  leader.followedBy = nil
  startMoveChain(house)
end
function lockAndScoreChain(head, score)
  if (not head) then return end
  head.locked = true
  head.wait = false
  head.score = score
  lockAndScoreChain(head.followedBy, score * 2)
end

function survivorPickupDetect()
  for i, surv in ipairs(survivors) do
    if    (not surv.locked) -- available for interaction
      and (not surv.panic or surv.panic < 1) -- calm enough to be rescued
      and sameTile(surv, player) -- just got walked over
    then -- we hit a survivor. build chain; if already in chain,
      --  scatter this one and their followers
      local leader = findInChain(player, surv)
      if (leader == nil) then -- a lone survivor, join the queue
        surv.followedBy = player.followedBy
        player.followedBy = surv
        surv.wait = true -- fix conga overlap
        surv.thinking = ""
      else -- we hit our conga line. everyone gets knocked off and set to panic
        bustChain(leader)
      end
    end
  end
end

function findInChain(chain, target)
  if (chain.followedBy == target) then return chain end
  if (chain.followedBy == nil) then return nil end
  return findInChain(chain.followedBy, target)
end

function bustChain(leader)
  local next = leader.followedBy
  leader.followedBy = nil
  if (next) then
    next.panic = 15 -- this many rounds until they can rejoin
    bustChain (next)
  end
end

-- Draw a frame
function love.draw()
  local zts = currentLevel.zoom * currentLevel.tiles.size
  playerCentreX = (screenWidth / 2) - (zts / 2)
  playerCentreY = (screenHeight / 2) - (zts / 2)

  love.graphics.setColor(255, 255, 255, 255)
  love.graphics.setFont(smallfont)
  local zoom = currentLevel.zoom
  local sceneX = mapOffset.x - zts * currentLevel.mapX
  local sceneY = mapOffset.y - zts * currentLevel.mapY

  -- assign all the active chars to a draw row, then pick them back out
  -- as we draw
  local charRows = {}

  for i,char in ipairs(zombies) do
    appendMap(charRows, char, level.posToRow(char, currentLevel))
  end
  for i,char in ipairs(survivors) do
    appendMap(charRows, char, level.posToRow(char, currentLevel))
  end
  appendMap(charRows, player, level.posToRow(player, currentLevel))

  -- todo: scan through rows, draw chars on or above the row
  --       then the fg row.
  for row = 1, currentLevel.rowsToDraw do
    level.drawBgRow(row, currentLevel, mapOffset)
    -- pick chars in slots
    if (charRows[row]) then
      for i,char in ipairs(charRows[row]) do
        if (char.color) then
          love.graphics.setColor(char.color.r, char.color.g, char.color.b, 255)
        else
            love.graphics.setColor(255, 255, 255, 255)
        end
        love.graphics.print(char.thinking, math.floor(sceneX + (char.x*zts)), math.floor(sceneY + (char.y+0.4)*zts), 0, zoom/2)
        char.anim:draw(creepSheet, sceneX + (char.x*zts), sceneY + ((char.y+0.8)*zts), 0, zoom)
      end
    end
    level.drawFgRow(row, currentLevel, mapOffset)
  end

  -- be nice to the gc, assuming it does fast gen 0
  charRows = nil

  drawControlHints()  --near last, the control outlines

  love.graphics.setColor(255, 255, 255, 255)
  love.graphics.print(GameScore, 10, 30, 0, zoom / 2)
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
