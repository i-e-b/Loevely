local anim8 = require "anim8" -- character animations
local flux = require "flux"   -- movement tweening. Modified from standard
local level = require "level"

-- todo: read this from settings file
local ShowTouchControls = love.system.getOS() == "Android"

local LevelFileName = "ztown.tmx"

local screenWidth, screenHeight, playerCentreX, playerCentreY

local GameScore = 0
local FeedingDuration = 3 -- shorter is harder

local creepSheet -- image that has all character frames
local smallfont  -- in game image font
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
    visible = true,       -- if false, char is not drawn (for warping)
    lifes = 3             -- when zero, it's game over (only player)
  --waiting = false       -- should skip the next follow turn (survivors)
  --panic = 0             -- how many rounds of panic left (survivors)
  --locked = false        -- character is locked into an animation, don't interact
  }

local mapOffset = {x = 1, y = 1} -- pixel offset for scrolling

-- Position of touch buttons:
local buttons = {up={230, 225}, down={230, 495}, left={100, 360}, right={370, 360}, action={1100,500}}
-- currently loaded level data
local currentLevel

-- Load non dynamic values
function love.load()
  screenWidth, screenHeight = love.graphics.getDimensions( )
  currentLevel = level.load(LevelFileName, screenWidth, screenHeight);

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
  protoZombie.anims['feedSurvivor'] = anim8.newAnimation(grid(7,'6-7'), 0.4)
  protoZombie.anims['feedPlayer'] = anim8.newAnimation(grid(7,'8-9'), 0.4)
  protoZombie.anims['sleep'] = anim8.newAnimation(grid(8,'6-7'), 0.7)

  player.anims['life'] = anim8.newAnimation(grid('1-2',11), {4,0.4})
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
      player.x = creep.x+1; player.y = creep.y
    elseif creep.type == 254 then -- zombie
      table.insert(zombies, makeZombie(creep.x, creep.y))
    elseif creep.type == 256 then -- survivor
      table.insert(survivors, makeSurvivor(creep.x, creep.y))
    end
  end
end

function love.keypressed(k)
	if k == 'escape' then
		love.event.push('quit') -- Quit the game.
  end
end

-- Update, with frame time in fractional seconds
function love.update(dt)
  updateZombies()
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

-- Draw a frame
function love.draw()
  local zts = currentLevel.zoom * currentLevel.tiles.size
  playerCentreX = (screenWidth / 2) - (zts / 2)
  playerCentreY = (screenHeight / 2) - (zts / 2)

  love.graphics.setColor(255, 255, 255, 255)
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
  if (player.visible) then
    appendMap(charRows, player, level.posToRow(player, currentLevel))
  end

  -- scan through rows, draw back ground, then chars, then the fg row.
  for row = 1, currentLevel.rowsToDraw do
    level.drawBgRow(row, currentLevel, mapOffset)
    -- pick chars in slots
    if (charRows[row]) then
      for i,char in ipairs(charRows[row]) do
        if (char.color) then -- tints
          love.graphics.setColor(char.color.r, char.color.g, char.color.b, 255)
        else
          love.graphics.setColor(255, 255, 255, 255)
        end
        centreSmallString(char.thinking, sceneX + ((char.x+0.5)*zts), sceneY + (char.y+0.4)*zts, zoom/4)
        char.anim:draw(creepSheet, sceneX + (char.x*zts), sceneY + ((char.y+0.8)*zts), 0, zoom)
      end
    end
    level.drawFgRow(row, currentLevel, mapOffset)
  end

  -- be nice to the gc, assuming it does fast gen 0
  charRows = nil

  drawControlHints()  --near last, the control outlines
  drawHUD()  -- FPS counter, score, survivor count - always last.
end

function makeZombie(x,y)
  local newAnims = {}
  for k,anim in pairs(protoZombie.anims) do
    newAnims[k] = anim:clone()
  end
  local z = {speed=1, x=x+1, y=y, moving=false, thinking="Gruh?", anims=newAnims}
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
    r = love.math.random(120,255),
    g = love.math.random(120,255),
    b = love.math.random(120,255),
  }

  return s
end

function updateAnimations(dt)
  flux.update(dt)
  for i,char in ipairs(zombies)   do char.anim:update(dt) end
  for i,char in ipairs(survivors) do char.anim:update(dt) end
  player.anim:update(dt)
  player.anims['life']:update(dt)
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
  if (math.abs(x - b[1]) < 100 and math.abs(y - b[2]) < 100)
  then return true else return false end
end
function triggerClick(x,y)
  if inButton(x,y,buttons.up) then input.up = true end
  if inButton(x,y,buttons.down) then input.down = true end
  if inButton(x,y,buttons.left) then input.left = true end
  if inButton(x,y,buttons.right) then input.right = true end
  if inButton(x,y,buttons.action) then input.action = true end
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
    elseif (surv.flee and surv.flee.dist < 2 and not surv.flux) then
      -- run away from zombies
      -- unless we're in a chain. We trust the player (fools...)
      if not findInChain(player, surv) then
        local fx,fy = nearestPassable(surv, surv.flee)
        startMove(surv, 1/surv.speed, fx,fy)
      end
    elseif (surv.panic > 0) and (not surv.moving) then -- run around in a mad panic
      surv.thinking = "A"..(string.rep('a',surv.panic)).."!"

        local dx=0
        local dy=0
        while (dx == 0) and (dy == 0) do
          dx = love.math.random( 1, 3 ) - 2
          dy = love.math.random( 1, 3 ) - 2
        end
        dx,dy = nearestPassable(surv, {x=surv.x+dx,y=surv.y+dy})
        startMove(surv, 1/surv.speed, dx, dy)
    end
  end
end

function updateZombies()
  local brains = {}
  if not player.locked then table.insert(brains, player) end
  for i,brain in ipairs(survivors) do
    if (not brain.locked) then -- safehouse chains can't be munched
      brain.flee = nil -- reset flee distance
      table.insert(brains, brain)
    end
  end

  for i, zom in ipairs(zombies) do
    -- Find the nearest brain within 5 moves, or wander aimlessly
    -- we set an artificial best candidate to define the wander and trigger radius
    local bestCandidate = {
      dist=6,
      x = math.random(1, currentLevel.width), -- generally tend to the middle
      y = math.random(1, currentLevel.height)
      --[[ x = zom.x + (math.random(0, 2) - 1), -- wander at random, less biased
      y = zom.y + (math.random(0, 2) - 1)]]
    }
    if (not zom.locked) then zom.thinking = "gruuh" end

    for j, brain in ipairs(brains) do
      -- inject 'run away' direction into the target
      local dist = math.abs(zom.x - brain.x) + math.abs(zom.y - brain.y) -- no diagonals, so manhattan distance is fine
      local dx, dy = pinCardinal(zom, brain) -- flee direction
      if (not brain.flee) or (brain.flee.dist > dist) then -- always flee the nearest zombie!
        brain.flee = {dist=dist, x=brain.x+dx, y=brain.y+dy}
      end

      if (dist < bestCandidate.dist) then
        if (not zom.locked) then zom.thinking = "Brains" end
        bestCandidate.dist = dist
        bestCandidate.char = brain
        bestCandidate.x = brain.x
        bestCandidate.y = brain.y
      end
    end

    if (not zom.locked) and (bestCandidate.dist < 0.8) then -- should be 1, but give some near miss
      local chain = findInChain(player, bestCandidate.char)
      if chain then
        bustChain(chain, 14) -- everyone panic!
      end
      feedZombie(zom, bestCandidate.char)  -- flip the animation, flux triggers back to normal
      removeSurvivor(bestCandidate.char)
    end

    if (not zom.moving) and (not zom.locked) then
      local dx, dy = nearestPassable(zom, bestCandidate)
      startMove(zom, 1/zom.speed, dx, dy)
    end
  end
end

function loseLife()
  -- todo: bash zombie away and return control.
  player.moving = false
  player.visible = true
  --error('oops, you died!')
end

function feedZombie(zombie, eaten)
  zombie.thinking = "om nom nom"

  if (zombie.flux) then zombie.flux:stop() end
  if (eaten.flux) then eaten.flux:stop() end
  zombie.moving = true
  zombie.locked = true

  zombie.x = near(eaten.x)
  zombie.y = near(eaten.y)
  eaten.x = near(eaten.x)
  eaten.y = near(eaten.y)

  if (player == eaten) then -- game over, man
    zombie.anim = zombie.anims['feedPlayer']
    player.visible = false
    if (player.flux) then player.flux:stop() end
    player.moving = true
    player.lifes = player.lifes - 1

    player.flux = flux.to(player, FeedingDuration, {x = player.x}):oncomplete(loseLife)
  else -- oops. Not a survivor anymore.
    zombie.anim = zombie.anims['feedSurvivor']
  end

  zombie.flux = flux.to(zombie, FeedingDuration, {x = zombie.x}):oncomplete(sleepZombie)
end

function sleepZombie(zombie)
  zombie.thinking = 'zzz'
  zombie.anim = zombie.anims['sleep']
  zombie.flux = flux.to(zombie, FeedingDuration, {x = zombie.x}):oncomplete(unlockZombie)
end

function unlockZombie(zombie)
  zombie.moving = false
  zombie.locked = false
end

function removeSurvivor(deadOne)
  for i, surv in ipairs(survivors) do
    if (surv == deadOne) then
      table.remove(survivors, i)
      GameScore = GameScore - 100 -- same as saving one.
      return
    end
  end
end

-- next passable direction (may go back, but doesn't look path finding)
function nearestPassable(chSrc, chDst)
    local dx = near(chDst.x - chSrc.x)
    local dy = near(chDst.y - chSrc.y)
    local prio; -- make a priority list, check each in turn

    if (dx == 0 and dy == 0) then return 0,0 end

    if (dx > 0) then dx1=1; dx2=-1 else dx2=1; dx1=-1 end
    if (dy > 0) then dy1=1; dy2=-1 else dy2=1; dy1=-1 end

    if (math.abs(dx) > math.abs(dy)) then
      prio = {{x=dx1,y=0}, {x=0,y=dy1}, {x=0,y=dy2}, {x=dx2, y=0}}
    else
      prio = {{x=0,y=dy1}, {x=dx1,y=0}, {x=dx2, y=0}, {x=0,y=dy2}}
    end

    for i,p in ipairs(prio) do
      if level.isPassable(currentLevel, chSrc, p.x, p.y) then
        return p.x, p.y
      end
    end
    return 0,0
end

function pinCardinal(chSrc, chDst)
  local dx = chDst.x - chSrc.x
  local dy = chDst.y - chSrc.y
  if (math.abs(dx) > math.abs(dy)) then
    if (dx > 0) then return 1,0
    else return -1,0 end
  else
    if (dy > 0) then return 0,1
    elseif (dy < 0) then return 0,-1
    else return 0,0 end
  end
end

function sameTile(chr1, chr2, c1dx, c1dy)
  local dx = c1dx or 0
  local dy = c1dy or 0
  return (near(chr1.x + dx) == near(chr2.x)) and (near(chr1.y + dy) == near(chr2.y))
end

-- handle actions based on pressed controls
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

  if input.action and (not player.warping) then
    -- test for a warp. If so, follow it.
    startWarp()
  elseif not input.action then
    player.thinking = ""
    player.warping = false -- lock out the warp until the control is lifted
  end

  -- check for obstructions, and start the move animation
  if not player.moving and (dx ~= 0 or dy ~= 0) then
    if (player.followedBy and sameTile(player, player.followedBy, dx, dy)) then
      -- trying to push back against the chain, panic them rather than blocking
      bustChain(player)
    end
    if (level.isPassable(currentLevel, player, dx, dy)) then
      player.moving = true
      startMove(player, 1/player.speed, dx, dy)
    else
      dx =  0; dy = 0
    end
  end
end

function near(a) return math.floor(a+0.5) end -- crap, but will do for map indexes

function startWarp()
  player.thinking = "?"
  local w = currentLevel.warps[near(player.x)]
  if  not w then return end
  local loc = w[near(player.y)]
  if not loc then return end

  bustChain(player) -- survivors won't follow you into the dark
  player.thinking = ""
  player.warping = true -- lock out the warp until the control is lifted
  player.locked = true  -- no munching in transit
  player.moving = true -- lock out movement until warp complete
  player.visible = false
  if player.flux then player.flux:stop() end
  player.flux = flux.to(player, 1, {x=loc.x, y=loc.y }):ease("quadinout"):oncomplete(endWarp)
end
function endWarp()
  player.anim = player.anims['stand']
  player.visible = true
  player.moving = false
  player.locked = false
end

function startMove(ch, duration, dx, dy)
  -- reset character movement
  if ch.flux then ch.flux:stop() end
  ch.moving = true -- so movement can be locked

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
  end
  ch.moving = false  -- unlock movement
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

-- find the leader of the target if it's in the chain
function findInChain(chain, target)
  if (chain.followedBy == target) then return chain end
  if (chain.followedBy == nil) then return nil end
  return findInChain(chain.followedBy, target)
end

function bustChain(leader, panicTurns)
  panicTurns = panicTurns or 8
  local next = leader.followedBy
  leader.followedBy = nil
  if (next) then
    next.locked = false
    next.panic = panicTurns -- this many rounds until they can rejoin or flee
    bustChain (next, panicTurns)
  end
end

function appendMap(arry, obj, index)
  if not arry[index] then
    arry[index] = {obj}
    return
  end
  table.insert(arry[index], obj)
end

function centreSmallString(str, x, y, scale)
  scale = scale or 1
  local w = scale * smallfont:getWidth(str) / 2
  love.graphics.setFont(smallfont)
  love.graphics.print(str, math.floor(x - w), math.floor(y), 0, scale)
end

function rightAlignSmallString(str, x, y)
  local w = smallfont:getWidth(str)
  love.graphics.setFont(smallfont)
  love.graphics.print(str, math.floor(x - w), math.floor(y))
end

function drawHUD()
  love.graphics.setFont(smallfont)

  love.graphics.setColor(255, 128, 0, 255)
  love.graphics.print("FPS: "..love.timer.getFPS(), 10, 5, 0, 0.5)

  love.graphics.setColor(255, 255, 255, 255)
  love.graphics.print("Score: "..GameScore, 10, 30)

  rightAlignSmallString("Remaining: "..table.getn(survivors), screenWidth-10, 30)

  player.anims['life']:draw(creepSheet, 10, screenHeight - 74, 0, 4)

end

function drawControlHints()
  if not ShowTouchControls then return end
  for itr = 0, 2 do
    love.graphics.setColor(itr*70, itr*70, itr*70, 200)
    -- directions
    love.graphics.circle("line", buttons.up[1] + itr, buttons.up[2], 100, 4)
    love.graphics.circle("line", buttons.down[1] + itr, buttons.down[2], 100, 4)
    love.graphics.circle("line", buttons.left[1] + itr, buttons.left[2], 100, 4)
    love.graphics.circle("line", buttons.right[1] + itr, buttons.right[2], 100, 4)
    -- action
    love.graphics.circle("line", buttons.action[1] + itr, buttons.action[2], 100, 6)
  end
end
