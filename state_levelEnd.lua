
local flux = require "flux"   -- movement tweening. Modified from standard


local assets -- local copy of game-wide assets
local screenWidth, screenHeight
local currentGame

function Initialise(coreAssets)
  assets = coreAssets
  screenWidth, screenHeight = love.graphics.getDimensions( )
end

function Update(dt)
  flux.update(dt)

  love.graphics.setColor(255, 255, 255, 255)
end

function LoadState(gameState)
  currentGame = gameState
end

function Draw()
  centreBigString("Level Complete", screenWidth / 2, 70, 2)

  local height = 240

  local left = screenWidth / 2 - 24
  local right = left + 48

  rightAlignSmallString("Time taken", left, height)
  love.graphics.print(math.ceil(currentGame.LevelTime) .. " seconds", right, height)

  height = height + 120
  rightAlignSmallString("Survivors rescued", left, height)
  love.graphics.print(currentGame.LevelSurvivorsRescued, right, height)

  height = height + 120
  rightAlignSmallString("Survivors eaten", left, height)
  love.graphics.print(currentGame.LevelSurvivorsEaten, right, height)

  height = height + 120
  rightAlignSmallString("Zombies minced", left, height)
  love.graphics.print(currentGame.LevelZombiesMinced, right, height)
end

-- todo> move these out to a common module?
function rightAlignSmallString(str, x, y)
  local w = assets.smallfont:getWidth(str)
  love.graphics.setFont(assets.smallfont)
  love.graphics.print(str, math.floor(x - w), math.floor(y))
end
function centreBigString(str, x, y, scale)
  scale = scale or 1
  local w = scale * assets.bigfont:getWidth(string.upper(str)) / 2
  love.graphics.setFont(assets.bigfont)
  -- big font has only caps, to we uppercase the input to save me from my own stupidity
  love.graphics.print(string.upper(str), math.floor(x - w), math.floor(y - (scale * 13.5)), 0, scale)
end


-- Level transition screen after success
return {
  Initialise = Initialise,
  Draw = Draw,
  Update = Update,
  LoadState = LoadState
}
