--[[
  Level transition screen after success.
  Shows a short summary of achievements
]]
local flux = require "flux"   -- movement tweening. Modified from standard


local assets -- local copy of game-wide assets
local screenWidth, screenHeight
local currentGame
local readyForContinue
local continueMessage

local Initialise, Update, LoadState, Draw, rightAlignString, centreBigString, centreSmallString

Initialise = function(coreAssets)
  if (love.system.getOS() == "Android") then
    continueMessage = "touch screen to continue"
  else
    continueMessage = "to continue, press any key or click mouse"
  end
  readyForContinue = false
  assets = coreAssets
  screenWidth, screenHeight = love.graphics.getDimensions( )
end

Update = function(dt, keyDownCount)
  flux.update(dt)

  if (readyForContinue) and (keyDownCount > 0) then
    currentGame.LevelShouldAdvance = true
  end
  if (keyDownCount < 1) then
    readyForContinue = true
  end
end

LoadState = function(gameState)
  currentGame = gameState
end

Draw = function()
  love.graphics.setColor(1, 1, 1, 1)

  love.graphics.setFont(assets.bigfont)
  centreBigString("* LEVEL COMPLETE *", screenWidth / 2, 70, 2)

  local height = 240

  local left = screenWidth / 2 - 24
  local right = left + 48

  love.graphics.setFont(assets.smallfont)
  love.graphics.setColor(0.66, 0.66, 0.66, 1)
  centreSmallString(continueMessage, screenWidth / 2, 120, 2)
  love.graphics.setColor(1, 1, 1, 1)

  rightAlignString("Score", left, height, 2)
  love.graphics.print(math.ceil(currentGame.Score), right, height, 0, 2)

  height = height + 70
  rightAlignString("Time taken", left, height, 2)
  love.graphics.print(math.floor(currentGame.LevelTime) .. " seconds", right, height, 0, 2)

  height = height + 70
  rightAlignString("Survivors rescued", left, height, 2)
  love.graphics.print(currentGame.LevelSurvivorsRescued, right, height, 0, 2)

  height = height + 70
  rightAlignString("Survivors eaten", left, height, 2)
  love.graphics.print(currentGame.LevelSurvivorsEaten, right, height, 0, 2)

  height = height + 70
  rightAlignString("Zombies minced", left, height, 2)
  love.graphics.print(currentGame.LevelZombiesMinced, right, height, 0, 2)
end

-- todo> move these out to a common module?
rightAlignString = function(str, x, y, scale)
  scale = scale or 1
  local w = scale * assets.smallfont:getWidth(str)
  love.graphics.print(str, math.floor(x - w), math.floor(y), 0,scale)
end
centreBigString = function(str, x, y, scale)
  scale = scale or 1
  local w = scale * assets.bigfont:getWidth(str) / 2
  love.graphics.print(str, math.floor(x - w), math.floor(y - (scale * 13.5)), 0, scale)
end
centreSmallString = function(str, x, y, scale)
  scale = scale or 1
  local w = scale * assets.smallfont:getWidth(str) / 2
  love.graphics.print(str, math.floor(x - w), math.floor(y), 0, scale)
end


return {
  Initialise = Initialise,
  Draw = Draw,
  Update = Update,
  LoadState = LoadState
}
