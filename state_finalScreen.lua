--[[
  This state is the game complete screen. A final 'well done'
  before returning to the main menu (once that's built)
]]

local flux = require "flux"

local assets -- local copy of game-wide assets
local screenWidth, screenHeight, currentGame

local Initialise,Update,LoadState,Draw,rightAlignString,centreString

Initialise = function(coreAssets)
  assets = coreAssets
  screenWidth, screenHeight = love.graphics.getDimensions( )
end

Update = function(dt, keyDownCount)
  flux.update(dt)

  if (keyDownCount > 0) then
    --currentGame.LevelShouldAdvance = true
  end

  love.graphics.setColor(255, 255, 255, 255)
end

LoadState = function(gameState)
  currentGame = gameState
end

Draw = function()
  love.graphics.setFont(assets.bigfont)
  centreString("* GAME COMPLETE *", screenWidth / 2, 70, 2)

  local height = 240

  local left = screenWidth / 2 - 24
  local right = left + 48

  love.graphics.setFont(assets.smallfont)
  love.graphics.setColor(255, 255, 255, 255)

  rightAlignString("Score", left, height, 2)
  love.graphics.print(math.ceil(currentGame.Score), right, height, 0, 2)

  height = height + 70
  rightAlignString("Time taken", left, height, 2)
  love.graphics.print(math.floor(currentGame.TotalTime) .. " seconds", right, height, 0, 2)

  height = height + 70
  rightAlignString("Survivors rescued", left, height, 2)
  love.graphics.print(currentGame.TotalSurvivorsRescued, right, height, 0, 2)

  height = height + 70
  rightAlignString("Survivors eaten", left, height, 2)
  love.graphics.print(currentGame.TotalSurvivorsEaten, right, height, 0, 2)

  height = height + 70
  rightAlignString("Zombies minced", left, height, 2)
  love.graphics.print(currentGame.TotalZombiesMinced, right, height, 0, 2)
end

-- todo> move these out to a common module?
rightAlignString = function(str, x, y, scale)
  scale = scale or 1
  local w = scale * assets.smallfont:getWidth(str)
  love.graphics.print(str, math.floor(x - w), math.floor(y), 0,scale)
end
centreString = function(str, x, y, scale)
  scale = scale or 1
  local w = scale * assets.bigfont:getWidth(str) / 2
  love.graphics.print(str, math.floor(x - w), math.floor(y - (scale * 13.5)), 0, scale)
end


return {
  Initialise = Initialise,
  Draw = Draw,
  Update = Update,
  LoadState = LoadState
}
