--[[
  This state is the game complete screen. A final 'well done'
  before returning to the main menu (once that's built)
]]

local flux = require "flux"

local assets -- local copy of game-wide assets
local screenWidth, screenHeight

function Initialise(coreAssets)
  assets = coreAssets
  screenWidth, screenHeight = love.graphics.getDimensions( )
end

function Update(dt, keyDownCount)
  flux.update(dt)

  if (keyDownCount > 0) then
    --currentGame.LevelShouldAdvance = true
  end

  love.graphics.setColor(255, 255, 255, 255)
end

function LoadState(gameState)
  currentGame = gameState
end

function Draw()
  love.graphics.setFont(assets.bigfont)
  centreString("* GAME COMPLETE *", screenWidth / 2, 70, 2)

  local height = 240

  local left = screenWidth / 2 - 24
  local right = left + 48

  love.graphics.setFont(assets.smallfont)
  rightAlignString("Time taken", left, height, 2)
  love.graphics.print(math.ceil(currentGame.TotalTime) .. " seconds", right, height, 0, 2)

  height = height + 120
  rightAlignString("Survivors rescued", left, height, 2)
  love.graphics.print(currentGame.TotalSurvivorsRescued, right, height, 0, 2)

  height = height + 120
  rightAlignString("Survivors eaten", left, height, 2)
  love.graphics.print(currentGame.TotalSurvivorsEaten, right, height, 0, 2)

  height = height + 120
  rightAlignString("Zombies minced", left, height, 2)
  love.graphics.print(currentGame.TotalZombiesMinced, right, height, 0, 2)
end

-- todo> move these out to a common module?
function rightAlignString(str, x, y, scale)
  scale = scale or 1
  local w = scale * assets.smallfont:getWidth(str)
  love.graphics.print(str, math.floor(x - w), math.floor(y), 0,scale)
end
function centreString(str, x, y, scale)
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
