-- Main game logic. These are hooks for the lua calls
-- for when you running around saving people from zombies

local anim8 = require "anim8" -- character animations
local flux = require "flux"   -- movement tweening. Modified from standard
local level = require "level" -- loading levels from .tmx files
local util = require "util"

-- todo: read this from settings file
local isPhone = love.system.getOS() == "Android" or love.system.getOS() == "iOS"
local screenWidth, screenHeight, playerCentreX, playerCentreY
local currentGame -- assumes one loaded at once!
local endLevelTransition -- doing an end of level animation

local assets -- local copy of game-wide assets
local zombies = {}
local survivors = {}
local coins = {}
local weapons = {}
local gui = {anims={}, bloodTint = 255}
local FeedingDuration = 3 -- shorter is harder

-- Position of touch buttons:
local buttons = {
  up={230, 225}, down={230, 495}, left={100, 360}, right={370, 360},
  action={1100,500}, menu={1312,0}
}
local gamepad = nil
local lastDx, lastDy --so we can bias the controls to make them feel nice
-- currently loaded level data
local currentLevel

local mapOffset = {x = 1, y = 1} -- pixel offset for scrolling

local flashes = {}     -- score animations, bump animations, tutorial text, etc
-- flash must have an x and y (in tile coords) and can have 'text','alpha','anim'
-- animations are from taken from the 'creeps' sheet.
-- flashes are not automatically removed.

local protoZombie = {anims={}}
local protoSurvivor = {anims={}}
local protoPlayer = { -- NPCs follow the same structure
  speed=4, x=2, y=2,  -- tile grid coords
  thinking="",          -- text above the character
  anims={},             -- animation sets against the 'creeps' image
  anim=nil,             -- current stance animation
  moving = false,       -- is player moving between tiles?
  warping = false,      -- is player roving around the sewers?
  followedBy = nil,     -- next element in survivor chain
  visible = true,       -- if false, char is not drawn (for warping and overlay animations)
  chainsawTime = 0      -- if > 0, we have the saw. Time counts down
  --waiting = false       -- should skip the next follow turn (survivors)
  --panic = 0             -- how many rounds of panic left (survivors)
  --locked = false        -- character is locked into an animation, don't interact
  --hidden = false        -- hidden, will only trigger if a player comes close (zombies)
}
local player = nil

local input = {wasGamePad=false, up=false, down=false, left=false, right=false, action=false}

--[[ Big list of functions to get around Lua global/local crap ]]
--[[ Hopefully, I can find a better way around this later      ]]
local Draw, Initialise, CreateNewGameState, AdvanceLevel, resetLevelCounters,
      makeZombie, makeSurvivor, updateAnimations, noSurvivorsLeft,
      levelComplete, inButton, triggerClick, readInputs, near, sameTile,
      inSafeHouse, shoveFlash, scoreFlash, removeFlash, updateSurvivors,
      updateZombies, raiseTheUndead, loseLife, unlockChar, feedZombie,
      sleepZombie, unlockZombie, removeSurvivor, nearestPassable,
      pinCardinal, startMove, endMove, startMoveChain, updateControl,
      startWarp, endWarp, escapeSurvivors, lockAndScoreChain, survivorEscapes,
      survivorPickupDetect, pickupSurvivor, findInChain, bustChain, appendMap,
      centreSmallString, centreBigString, rightAlignSmallString, drawHUD,
      drawControlHints, coinPickupDetect, killZombie;


-- Load assets and do load-time stuff
-- Call this before anything else
Initialise = function(coreAssets)
  assets = coreAssets
  screenWidth, screenHeight = love.graphics.getDimensions( )

  local sw = assets.creepSheet:getWidth()
  local sh = assets.creepSheet:getHeight()

  local grid = anim8.newGrid(17, 18, sw, sh, 0, 0)

  gui.anims['life'] = anim8.newAnimation(grid('1-2',11), {4,0.4})
  gui.anims['remaining'] = anim8.newAnimation(grid('1-3',12), 1.4)
  gui.anims['coin'] = anim8.newAnimation(grid(10,'6-8', 10,'8-6'), 0.1)
  gui.anims['chainsaw'] = anim8.newAnimation(grid(13,'1-2'), 0.1)

  protoZombie.anims['down'] = anim8.newAnimation(grid('9-12',1), 0.2)
  protoZombie.anims['right'] = anim8.newAnimation(grid('9-12',2), 0.2)
  protoZombie.anims['left'] = anim8.newAnimation(grid('9-12',3), 0.2)
  protoZombie.anims['up'] = anim8.newAnimation(grid('9-12',4), 0.2)
  protoZombie.anims['stand'] = anim8.newAnimation(grid(7,'1-4'), 0.7)
  protoZombie.anims['feedSurvivor'] = anim8.newAnimation(grid(7,'6-7'), 0.4)
  protoZombie.anims['feedPlayer'] = anim8.newAnimation(grid(7,'8-9'), 0.4)
  protoZombie.anims['sleep'] = anim8.newAnimation(grid(8,'6-7'), 0.7)
  protoZombie.anims['raise'] = anim8.newAnimation(grid(8,'8-10'), 0.333, 'pauseAtEnd')
  protoZombie.anims['slain'] = anim8.newAnimation(grid(8,9), 1)

  protoPlayer.anims['shove'] = anim8.newAnimation(grid(9,'6-11'), 0.04, 'pauseAtEnd')
  protoPlayer.anims['down'] = anim8.newAnimation(grid('1-4',1), 0.1)
  protoPlayer.anims['right'] = anim8.newAnimation(grid('1-4',2), 0.1)
  protoPlayer.anims['left'] = anim8.newAnimation(grid('1-4',3), 0.1)
  protoPlayer.anims['up'] = anim8.newAnimation(grid('1-4',4), 0.1)
  protoPlayer.anims['stand'] = anim8.newAnimation(grid(6,'1-3', 6,1, 6,4), {0.8,0.4,0.4,0.7,0.2})
  protoPlayer.anims['chain-down'] = anim8.newAnimation(grid('11-14',6), 0.1)
  protoPlayer.anims['chain-right'] = anim8.newAnimation(grid('11-14',7), 0.1)
  protoPlayer.anims['chain-left'] = anim8.newAnimation(grid('11-14',8), 0.1)
  protoPlayer.anims['chain-up'] = anim8.newAnimation(grid('11-14',9), 0.1)
  protoPlayer.anims['chain-stand'] = anim8.newAnimation(grid(16,'6-8', 16,6, 16,9), {0.8,0.4,0.4,0.7,0.2})
  protoPlayer.anim = protoPlayer.anims['stand']

  protoSurvivor.anims['down'] = anim8.newAnimation(grid('1-4',6), 0.1)
  protoSurvivor.anims['right'] = anim8.newAnimation(grid('1-4',7), 0.1)
  protoSurvivor.anims['left'] = anim8.newAnimation(grid('1-4',8), 0.1)
  protoSurvivor.anims['up'] = anim8.newAnimation(grid('1-4',9), 0.1)
  protoSurvivor.anims['help'] = anim8.newAnimation(grid(6,'6-9'), 0.4)
  protoSurvivor.anims['stand'] = anim8.newAnimation(grid(6,'6-7'), 1)
end


-- Load a gameState and level ready for play.
-- Start calling Draw() and Update() to run the level
LoadState = function(levelName, gameState)
  -- reset per level stuff
  mapOffset = {x = 1, y = 1} -- pixel offset for scrolling
  flashes = {}
  zombies = {}
  survivors = {}
  coins = {}
  weapons = {}
  player = deepcopy(protoPlayer)

  currentGame = gameState
  currentLevel = level.load("assets/"..levelName, screenWidth, screenHeight);

  playerCentreX = (screenWidth / 2) - (currentLevel.zoom * currentLevel.tiles.size / 2)
  playerCentreY = (screenHeight / 2) - (currentLevel.zoom * currentLevel.tiles.size / 2)

  for i,creep in ipairs(currentLevel.placement) do
    if creep.type == 255 then -- player
      player.x = creep.x; player.y = creep.y
    elseif creep.type == 254 then -- zombie
      table.insert(zombies, makeZombie(creep.x, creep.y, false))
    elseif creep.type == 253 then -- hidden zombie
      table.insert(zombies, makeZombie(creep.x, creep.y, true))
    elseif creep.type == 252 then -- tutorial survivor, doen't need to be saved
      table.insert(survivors, makeSurvivor(creep.x, creep.y, false))
    elseif creep.type == 256 then -- survivor
      table.insert(survivors, makeSurvivor(creep.x, creep.y, true))
    elseif creep.type == 251 then -- coin
      table.insert(coins, {anim=gui.anims['coin'], x=creep.x, y=creep.y})
    elseif creep.type == 250 then -- chainsaw
      table.insert(weapons, {anim=gui.anims['chainsaw'], x=creep.x, y=creep.y})
    end
  end

  for _,flash in pairs(currentLevel.infoFlash) do
    table.insert(flashes, flash)
  end
end

Draw = function()
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

  if (currentGame.Lives > 0) then
    -- TODO: only add on-screen chars to `charRows`
    for _,char in ipairs(coins) do
      if char then
        appendMap(charRows, char, level.posToRow(char, currentLevel))
      end
    end
    for _,char in ipairs(zombies) do
      if (not char.hidden) then
        appendMap(charRows, char, level.posToRow(char, currentLevel))
      end
    end
    for _,char in ipairs(weapons) do
      if char then
        appendMap(charRows, char, level.posToRow(char, currentLevel))
      end
    end
    for _,char in ipairs(survivors) do
      appendMap(charRows, char, level.posToRow(char, currentLevel))
    end
    if (player.visible) then
      appendMap(charRows, player, level.posToRow(player, currentLevel))
    end
  end

  -- scan through rows, draw back ground, then chars, then the fg row.
  for row = 1, currentLevel.rowsToDraw do
    level.drawBgRow(row, currentLevel, mapOffset, gui.bloodTint)
    -- pick chars in slots
    if (charRows[row]) then
      for i=1, #charRows[row] do
        local char = (charRows[row])[i]
        if (char.color and not endLevelTransition) then -- tints
          love.graphics.setColor(char.color.r, char.color.g, char.color.b, 255)
        else
          love.graphics.setColor(255, gui.bloodTint, gui.bloodTint, 255)
        end
        if (char.thinking) then
          centreSmallString(char.thinking,sceneX + (char.x+0.5)*zts,sceneY + (char.y+0.4)*zts,zoom/2)
        end


        char.anim:draw(
          assets.creepSheet,
          math.floor(sceneX + char.x*zts),
          math.floor(sceneY + (char.y+0.8)*zts),
          0, zoom
        )
      end
    end
    level.drawFgRow(row, currentLevel, mapOffset, gui.bloodTint)
  end

  -- be nice to the gc, assuming it does fast gen 0
  charRows = nil

  -- draw any 'flashes'
  for i, flash in ipairs(flashes) do
    love.graphics.setColor(255, 255, 255, (flash.alpha or 255))
    if (flash.text) then
      centreSmallString(flash.text, sceneX + zts * (flash.x+0.5), sceneY + zts * flash.y, zoom / 2)
    end
    if (flash.anim) then
      flash.anim:draw(assets.creepSheet, sceneX + zts * flash.x, sceneY + zts * flash.y, 0, zoom)
    end
  end

  drawControlHints()  --near last, the control outlines
  drawHUD()  -- FPS counter, score, survivor count - always last.
end

Update = function(dt, _, connectedPad)
  gamepad = connectedPad
  if (noSurvivorsLeft()) and not endLevelTransition then -- level complete
    endLevelTransition = true
    flux.to(gui, 2, {bloodTint = 0}):ease("linear"):oncomplete(levelComplete)
  end

  updateAnimations(dt) -- always do this first or the animations can get glitchy
  if (currentGame.Lives < 1) then
    return
  end

  if (dt < 0.5) and (not endLevelTransition) then -- don't count when paused or background
    currentGame.LevelTime = currentGame.LevelTime + dt -- drift, here we come!
  end

  if (endLevelTransition) then return end

  updateZombies()
  updateSurvivors()
  readInputs()
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

-- Create an initial game state (this persists between levels)
CreateNewGameState = function()
  return {
    Score = 0,
    Lives = 5, -- when zero, it's game over
    Level = 5, -- by default, skip the tutorial levels
    LevelComplete = false,      -- end of level state
    LevelShouldAdvance = false, -- begin next level
    LevelTime = 0,
    LevelSurvivorsEaten = 0,
    LevelSurvivorsRescued = 0,
    LevelZombiesMinced = 0,
    TotalZombiesMinced = 0,
    TotalSurvivorsRescued = 0,
    TotalSurvivorsEaten = 0,
    TotalTime = 0
  }
end

AdvanceLevel = function(gameState)
  gameState.TotalTime = gameState.TotalTime + gameState.LevelTime
  gameState.TotalSurvivorsEaten = gameState.TotalSurvivorsEaten + gameState.LevelSurvivorsEaten
  gameState.TotalSurvivorsRescued = gameState.TotalSurvivorsRescued + gameState.LevelSurvivorsRescued
  gameState.TotalZombiesMinced = gameState.TotalZombiesMinced + gameState.LevelZombiesMinced

  gameState.LevelComplete = false
  gameState.LevelShouldAdvance = false
  gameState.Level = gameState.Level + 1

  resetLevelCounters(gameState)
  endLevelTransition = false
  gui.bloodTint = 255
end

resetLevelCounters = function(gameState)
  gameState.LevelTime = 0
  gameState.LevelSurvivorsEaten = 0
  gameState.LevelSurvivorsRescued = 0
  gameState.LevelZombiesMinced = 0
end

makeZombie = function(x,y, hidden)
  local newAnims = {}
  for k,anim in pairs(protoZombie.anims) do
    newAnims[k] = anim:clone()
  end
  local z = {speed=1, x=x, y=y, moving=false, thinking="", anims=newAnims, hidden=hidden}
  z.anim = newAnims['stand']
  return z
end

makeSurvivor = function(x,y, needsSaving)
  local newAnims = {}
  for k,anim in pairs(protoSurvivor.anims) do
    newAnims[k] = anim:clone()
  end
  local s = {speed=4, score=100, x=x, y=y, thinking="Help!", anims=newAnims, panic = 0, needsSaving=needsSaving}
  s.anim = newAnims['help']

  s.color = {
    r = love.math.random(140,255),
    g = love.math.random(70,220),
    b = love.math.random(70,220),
  }

  return s
end

updateAnimations = function(dt)
  flux.update(dt)
  for i,char in ipairs(zombies)   do char.anim:update(dt) end
  for i,char in ipairs(survivors) do char.anim:update(dt) end
  for i,anim in pairs(gui.anims)  do anim:update(dt) end
  for i,flash in ipairs(flashes)  do if (flash.anim) then flash.anim:update(dt) end end

  player.anim:update(dt)
end

noSurvivorsLeft = function()
  if (not currentLevel.isTutorial) and (table.getn(survivors) < 1) then
    return true
  elseif (not currentLevel.isTutorial) then
    return false
  else
    for _,surv in ipairs(survivors) do
      if (surv.needsSaving) then return false end
    end
    return true
  end
end

levelComplete = function()
  currentGame.LevelComplete = true
  if (currentLevel.isTutorial) then
    currentGame.LevelShouldAdvance = true -- no end screen
    resetLevelCounters(currentGame) -- score and time don't count
    currentGame.Score = 0
    currentGame.Lives = 5
  end
end

inButton = function(x,y,b)
  if (math.abs(x - b[1]) < 110 and math.abs(y - b[2]) < 110)
  then return true else return false end
end
triggerClick = function(x,y)
  if inButton(x,y,buttons.up) then input.up = true end
  if inButton(x,y,buttons.down) then input.down = true end
  if inButton(x,y,buttons.left) then input.left = true end
  if inButton(x,y,buttons.right) then input.right = true end
  if inButton(x,y,buttons.action) then input.action = true end
  if inButton(x,y,buttons.menu) then love.event.push('gamePause') end
end

readInputs = function()
  input.up = love.keyboard.isDown("up")
  input.down = love.keyboard.isDown("down")
  input.left = love.keyboard.isDown("left")
  input.right = love.keyboard.isDown("right")
  input.action = love.keyboard.isDown("lctrl")

  if gamepad then
    -- currently hard-coded to my own game pad
    -- TODO: config screen should be able to set this
    local dx = gamepad:getAxis(1)
    local dy = gamepad:getAxis(2)
    if dx == 1 then input.right = true; input.wasGamePad = true end
    if dx == -1 then input.left = true; input.wasGamePad = true end
    if dy == 1 then input.down = true; input.wasGamePad = true end
    if dy == -1 then input.up = true; input.wasGamePad = true end
    if gamepad:isDown(1,2,3,4) then input.action = true end
  end

  -- if press in a special area, that input goes true
  if love.mouse.isDown(1) then
    triggerClick(love.mouse.getPosition())
  end

  local touches = love.touch.getTouches()
  for i, id in ipairs(touches) do
    triggerClick(love.touch.getPosition(id))
  end
end

near = function(a)
  return math.floor(a+0.5) -- crap, but will do for map indexes
end

sameTile = function(chr1, chr2, c1dx, c1dy)
  local dx = c1dx or 0
  local dy = c1dy or 0
  return (near(chr1.x + dx) == near(chr2.x)) and (near(chr1.y + dy) == near(chr2.y))
end

inSafeHouse = function(chr)
  for i,sh in ipairs(currentLevel.safeHouses) do
    if sameTile(chr, sh) then -- unhook the chain
      return sh
    end
  end
  return nil
end

shoveFlash = function(player, surv)
  local x = (player.x - surv.x) / 2 + surv.x
  local y = (player.y - surv.y) / 2 + surv.y + 1
  local flash = {
    x = x, y = y,
    alpha = 255,
    anim = player.anims['shove']:clone()
  }
  flux.to(flash, 0.3, {alpha = flash.alpha}):oncomplete(removeFlash)

  love.audio.play(assets.shoveSnd)
  table.insert(flashes, flash)
end

scoreFlash = function(num, x, y)
  local flash = {
    x = x, y = y,
    alpha = 255, text = "+"..num
  }
  flux.to(flash, 1, {y = y-1, alpha = 0}):oncomplete(removeFlash)
  table.insert(flashes, flash)
end

removeFlash = function(flash)
  for i,v in ipairs(flashes) do
    if (v == flash) then table.remove(flashes, i); return end
  end
end

updateSurvivors = function()
  for i = #survivors, 1, -1 do
    local surv = survivors[i]

    -- quick check to remove overlaps
    if (surv.followedBy) then
      if (surv.x == surv.followedBy.x) and (surv.y == surv.followedBy.y) then
        surv.followedBy.waiting = true
      end
    end

    local safe = inSafeHouse(surv)
    if safe then
      survivorEscapes(surv, i, safe)
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

updateZombies = function()
  local brains = {}
  if not player.locked then table.insert(brains, player) end
  for i,brain in ipairs(survivors) do
    if (not brain.locked) then -- safehouse chains can't be munched
      brain.flee = nil -- reset flee distance
      table.insert(brains, brain)
    end
  end

  for i, zom in ipairs(zombies) do
    if not zom.dead then -- stupid lack of continue
      -- Find the nearest brain within 5 moves, or wander aimlessly
      -- we set an artificial best candidate to define the wander and trigger radius
      local bestCandidate = {
        dist=6,
        --[[x = math.random(1, currentLevel.width), -- generally tend to the middle
        y = math.random(1, currentLevel.height)]]
        --[[]] x = zom.x + math.random(-2, 2), -- wander at random, less biased
        y = zom.y + math.random(-2, 2)
      }
      if (not zom.locked) then zom.thinking = "" end

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
      -- Now we have the nearest target

      if (zom.hidden) then
        if (bestCandidate.dist < 4.4) then
          raiseTheUndead(zom)
        end
      elseif (not zom.locked) and (bestCandidate.dist < 0.8) then -- should be 1, but give some near miss
        local chain = findInChain(player, bestCandidate.char)
        if (bestCandidate.char == player) then chain = player end
        if (chain.chainsawTime and chain.chainsawTime > 0) then -- bye zombie
          killZombie(zom)
        else -- feed the zombie
          if chain then
            bustChain(chain, 14) -- everyone panic!
          end
          feedZombie(zom, bestCandidate.char)  -- flip the animation, flux triggers back to normal
          removeSurvivor(bestCandidate.char)
        end
      elseif (not zom.moving) and (not zom.locked) then
        local dx, dy = nearestPassable(zom, bestCandidate)
        startMove(zom, 1/zom.speed, dx, dy)
      end
    end
  end
end

raiseTheUndead = function(zombie)
  zombie.locked = true
  zombie.hidden = false
  zombie.anim = zombie.anims['raise']
  zombie.flux = flux.to(zombie, 1, {x=zombie.x}):oncomplete(unlockZombie)
end

loseLife = function()
  player.moving = false
  player.visible = true

  currentGame.Lives = currentGame.Lives - 1
end

unlockChar = function(ch)
  ch.locked = false
end

killZombie = function(zombie)
  if zombie.flux then zombie.flux:stop() end -- they can be off-grid now
  currentGame.LevelZombiesMinced = currentGame.LevelZombiesMinced + 1
  zombie.thinking = ''
  zombie.anim = zombie.anims['slain']
  zombie.moving = false
  zombie.locked = true -- and no unlock trigger
  zombie.dead = true
end

feedZombie = function(zombie, eaten)
  zombie.thinking = "om nom nom"

  if (zombie.flux) then zombie.flux:stop() end
  if (eaten.flux) then eaten.flux:stop() end
  zombie.moving = true
  zombie.locked = true

  zombie.x = near(eaten.x)
  zombie.y = near(eaten.y)
  eaten.x = near(eaten.x)
  eaten.y = near(eaten.y)

  love.audio.loop(assets.munchSnd, 4, 0.8)

  if (player == eaten) then -- game over, man
    zombie.anim = zombie.anims['feedPlayer']
    zombie.anim:gotoFrame(2)

    player.anim = player.anims['stand']
    player.visible = false
    if (player.flux) then player.flux:stop() end
    player.moving = true
    player.locked = true

    if (currentGame.Lives == 1) then -- about to die. Start a fade-out
      flux.to(gui, FeedingDuration * 2, {bloodTint = 0}):ease("linear")
    end
    player.flux = flux.to(player, FeedingDuration*1.4, {x = player.x}):oncomplete(unlockChar)
    player.flux = flux.to(player, FeedingDuration, {x = player.x}):oncomplete(loseLife)
  else -- oops. Not a survivor anymore.
    currentGame.LevelSurvivorsEaten = currentGame.LevelSurvivorsEaten + 1
    zombie.anim = zombie.anims['feedSurvivor']
    zombie.anim:gotoFrame(2)
  end

  zombie.flux = flux.to(zombie, FeedingDuration, {x = zombie.x}):oncomplete(sleepZombie)
end

sleepZombie = function(zombie)
  zombie.thinking = 'zzz'
  zombie.anim = zombie.anims['sleep']
  zombie.flux = flux.to(zombie, FeedingDuration, {x = zombie.x}):oncomplete(unlockZombie)
end

unlockZombie = function(zombie)
  zombie.anim = zombie.anims['stand']
  zombie.moving = false
  zombie.locked = false
end

removeSurvivor = function(deadOne)
  for i, surv in ipairs(survivors) do
    if (surv == deadOne) then
      table.remove(survivors, i)
      currentGame.Score = currentGame.Score - 100 -- same as saving one.
      return
    end
  end
end

-- next passable direction (may go back, but doesn't look path finding)
nearestPassable = function(chSrc, chDst)
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

pinCardinal = function(chSrc, chDst)
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

startMoveChain = function(ch, duration)
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

endMove = function(ch)
  -- return to idle animation
  if (ch.chainsawTime and ch.chainsawTime > 0) then
    ch.anim = ch.anims['chain-stand']
  else
    ch.anim = ch.anims['stand']
  end
  ch.flux = nil

  -- reduce panic (survivors)
  if (ch.panic and ch.panic > 0) then
    ch.panic = ch.panic - 1
    if (ch.panic < 1) then ch.thinking = "Help!"; ch.anim = ch.anims['help'] end
  end

  if (ch == player) then
    survivorPickupDetect()
    coinPickupDetect()
    local house = inSafeHouse(player)
    if house then escapeSurvivors(player, house) end
  end
  ch.moving = false  -- unlock movement
end

startMove = function (ch, duration, dx, dy)
  -- reset character movement
  if ch.flux then ch.flux:stop() end
  ch.moving = true -- so movement can be locked

  local ischain = ''
  if (ch.chainsawTime and ch.chainsawTime > 0) then ischain = 'chain-' end

  -- set directional animation
  if (dx == 1) then ch.anim = ch.anims[ischain..'right']
  elseif (dx == -1) then ch.anim = ch.anims[ischain..'left']
  elseif (dy == 1) then ch.anim = ch.anims[ischain..'down']
  elseif (dy == -1) then ch.anim = ch.anims[ischain..'up'] end

  -- move to next tile
  ch.flux = flux.to(ch, duration, {x=ch.x+dx, y=ch.y+dy })
  :ease("linear"):oncomplete(endMove)

  -- update the chain
  startMoveChain(ch, duration)
end

-- handle actions based on pressed controls
updateControl = function()
  local dx = 0
  local dy = 0
  if input.up    then dy = -1; end
  if input.down  then dy =  1; end
  if input.left  then dx = -1; end
  if input.right then dx =  1; end

  if (lastDx == 0 and lastDy == 0) then lastDx = 1 end

  -- if we are using a pad-like control, we bias to continue the
  -- current direction. If we are using keyboard controls, we
  -- then bias to change direction. This suits each style best
  if input.wasGamePad then
    if (lastDx ~= 0 and dx ~= 0) then dy = 0 end
    if (lastDy ~= 0 and dy ~= 0) then dx = 0 end
  else
    if (lastDy ~= 0 and dx ~= 0) then dy = 0 end
    if (lastDx ~= 0 and dy ~= 0) then dx = 0 end
  end

  if input.action and (not player.warping) then
    -- test for a warp. If so, follow it.
    startWarp()
  elseif not input.action then
    player.thinking = ""
    player.warping = false -- lock out the warp until the control is lifted
  end

  -- check for obstructions, and start the move animation
  if not player.moving then
    if (dx ~= 0 or dy ~= 0) then
      if (player.followedBy and sameTile(player, player.followedBy, dx, dy)) then
        -- trying to push back against the chain, panic them rather than blocking
        shoveFlash(player, player.followedBy)
        bustChain(player)
      end
      if (level.isPassable(currentLevel, player, dx, dy)) then
        player.moving = true
        love.audio.replay(assets.walkSnd)
        startMove(player, 1/player.speed, dx, dy)
      else
        dx =  0; dy = 0
      end
    end

    lastDx = dx
    lastDy = dy
  end
end

startWarp = function()
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
endWarp = function()
  player.anim = player.anims['stand']
  player.visible = true
  player.moving = false
  player.locked = false
end

escapeSurvivors = function(leader, house)
  lockAndScoreChain(leader.followedBy, 100)
  house.followedBy = leader.followedBy
  leader.followedBy = nil
  startMoveChain(house)
end
lockAndScoreChain = function(head, score)
  if (not head) then return end
  head.locked = true
  head.wait = false
  head.score = score
  lockAndScoreChain(head.followedBy, score * 2)
end

survivorEscapes = function(surv, index, safehouse)
  love.audio.replay(assets.saveSnd)
  scoreFlash(surv.score, surv.x, surv.y)
  currentGame.Score = currentGame.Score + surv.score
  table.remove(survivors, index)
  currentGame.LevelSurvivorsRescued = currentGame.LevelSurvivorsRescued + 1
  if (surv.followedBy) then
    startMoveChain(safehouse)
    safehouse.followedBy = surv.followedBy
  end
end

coinPickupDetect = function()
  for i=1, #coins do
    local coin = coins[i]
    if coin and sameTile(player, coin) then
      table.remove(coins, i)
      love.audio.play(assets.coinSnd)
      currentGame.Score = currentGame.Score + 10
    end
  end
end

survivorPickupDetect = function()
  for i, surv in ipairs(survivors) do
    if    (not surv.locked) -- available for interaction
    and (not surv.panic or surv.panic < 1) -- calm enough to be rescued
    and sameTile(surv, player) -- just got walked over
    then -- we hit a survivor. build chain; if already in chain,
      --  scatter this one and their followers
      local leader = findInChain(player, surv)
      if (leader == nil) then -- a lone survivor, join the queue
        pickupSurvivor(surv)
      else -- we hit our conga line. everyone gets knocked off and set to panic
        shoveFlash(player, surv)
        bustChain(leader)
      end
    end
  end
end

pickupSurvivor = function(surv)
  love.audio.play(assets.pickupSnd)
  surv.followedBy = player.followedBy
  player.followedBy = surv
  surv.wait = true -- fix conga overlap
  surv.thinking = ""
end

-- find the leader of the target if it's in the chain
findInChain = function(chain, target)
  if (chain.followedBy == target) then return chain end
  if (chain.followedBy == nil) then return nil end
  return findInChain(chain.followedBy, target)
end

bustChain = function(leader, panicTurns)
  panicTurns = panicTurns or 8
  local next = leader.followedBy
  leader.followedBy = nil
  if (next) then
    next.locked = false
    next.panic = panicTurns -- this many rounds until they can rejoin or flee
    bustChain (next, panicTurns)
  end
end

appendMap = function(arry, obj, index)
  if not arry[index] then
    arry[index] = {obj}
    return
  end
  table.insert(arry[index], obj)
end

centreSmallString = function(str, x, y, scale)
  scale = scale or 1
  local w = scale * assets.smallfont:getWidth(str) / 2
  love.graphics.setFont(assets.smallfont)
  love.graphics.print(str, math.floor(x - w), math.floor(y), 0, scale)
end
centreBigString = function(str, x, y, scale)
  scale = scale or 1
  local w = scale * assets.bigfont:getWidth(string.upper(str)) / 2
  love.graphics.setFont(assets.bigfont)
  love.graphics.print(string.upper(str), math.floor(x - w), math.floor(y - (scale * 13.5)), 0, scale)
end

rightAlignSmallString = function(str, x, y, scale)
  scale = scale or 1
  local w = assets.smallfont:getWidth(str) * scale
  love.graphics.setFont(assets.smallfont)
  love.graphics.print(str, math.floor(x - w), math.floor(y), 0, scale)
end

drawHUD = function()
  love.graphics.setFont(assets.smallfont)

  love.graphics.setColor(255, 128, 0, 255)
  love.graphics.print("FPS: "..love.timer.getFPS(), 10, 5, 0, 1)

  love.graphics.setColor(255, 255, 255, 255)
  love.graphics.print("Score: "..currentGame.Score, 10, 30, 0, 2)

  centreSmallString(math.floor(currentGame.LevelTime), screenWidth/2, 30, 2)


  gui.anims['remaining']:draw(assets.creepSheet, screenWidth-74, 14, 0, 4)
  rightAlignSmallString(table.getn(survivors), screenWidth-84, 30, 2)

  gui.anims['life']:draw(assets.creepSheet, 10, screenHeight - 74, 0, 4)
  love.graphics.print(currentGame.Lives, 84, screenHeight - 50, 0, 2)

  if (currentGame.Lives < 1) then centreBigString("GAME OVER", screenWidth/2,screenHeight/2,4) end
end

drawControlHints = function()
  if not isPhone then return end
  for itr = 0, 2 do
    love.graphics.setColor(itr*70, itr*70, itr*70, 200)
    -- directions
    love.graphics.circle("line", buttons.up[1] + itr, buttons.up[2], 100, 4)
    love.graphics.circle("line", buttons.down[1] + itr, buttons.down[2], 100, 4)
    love.graphics.circle("line", buttons.left[1] + itr, buttons.left[2], 100, 4)
    love.graphics.circle("line", buttons.right[1] + itr, buttons.right[2], 100, 4)
    -- action
    love.graphics.circle("line", buttons.action[1] + itr, buttons.action[2], 100, 6)
    love.graphics.circle("line", buttons.menu[1] + itr, buttons.menu[2], 100, 6)
  end
end

return {
  Initialise = Initialise,
  CreateNewGameState = CreateNewGameState,
  LoadState = LoadState,
  AdvanceLevel = AdvanceLevel,
  Draw = Draw,
  Update = Update
}
