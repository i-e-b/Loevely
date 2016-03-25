--[[
  Load/New/Configure: the first screen on loading
]]
local flux = require "flux"   -- movement tweening. Modified from standard


local assets -- local copy of game-wide assets
local screenWidth, screenHeight
local currentGame
local readyForInput

local Initialise, Update, LoadState, Draw,
rightAlignString, centreBigString, centreSmallString

Initialise = function(coreAssets)
  readyForInput = false
  assets = coreAssets
  screenWidth, screenHeight = love.graphics.getDimensions( )
end

Update = function(dt, keyDownCount)
  -- TODO TEMP: for now, just continue to the game
  if (keyDownCount > 0) then love.event.push('gameResume') end

  if keyDownCount < 1 then readyForInput = true end
  flux.update(dt)
end

LoadState = function(gameState)
  -- todo: load, create new, save, etc.
  currentGame = gameState
end

Draw = function()
  love.graphics.setColor(255, 255, 255, 255)

  love.graphics.setFont(assets.bigfont)
  centreBigString("SURVIVOR", screenWidth / 2, 70, 3)

  love.graphics.setFont(assets.smallfont)
  love.graphics.setColor(170, 170, 170, 255)
  centreSmallString("snake meets pacman with zombies", screenWidth / 2, 120, 2)

  local height = 240
  local xpos = screenWidth / 2
  love.graphics.setColor(255, 255, 255, 255)

  centreSmallString("> New Game  ", xpos, height, 2)

  height = height + 100
  centreSmallString("  Load Game  ", xpos, height, 2)

  height = height + 100
  centreSmallString("  Tutorial  ", xpos, height, 2)

  height = height + 100
  centreSmallString("  Configure  ", xpos, height, 2)
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
