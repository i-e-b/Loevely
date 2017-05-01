--[[
  Configure screen: change configuration
]]
local flux = require "flux"   -- movement tweening. Modified from standard


local assets -- local copy of game-wide assets
local screenWidth, screenHeight
local currentGame
local readyForInput
local selection = 1

local Initialise, Update, LoadState, Draw, Reset, triggerClick, triggerAction,
rightAlignString, centreBigString, centreSmallString, toggleAudio

Initialise = function(coreAssets)
  readyForInput = false
  assets = coreAssets
  screenWidth, screenHeight = love.graphics.getDimensions()
  Reset()
end

Reset = function()
  selection = 1
end

Update = function(dt, keyDownCount)
  if keyDownCount < 1 then readyForInput = true end
  if not readyForInput then return end
  if keyDownCount > 0 then readyForInput = false end

  local delta = 0
  -- PAD AND KEYBOARD: these have a two stage select and activate
  if love.keyboard.isDown("up") then delta = -1 end
  if love.keyboard.isDown("down") then delta = 1 end

  local doAction = love.keyboard.isDown("lctrl","return","space")

  if (gamepad) then
    -- currently hard-coded to my own game pad
    -- TODO: config screen should be able to set this
    local dy = gamepad:getAxis(2)
    if dy == 1 then delta = 1 end
    if dy == -1 then delta = -1 end
    if gamepad:isDown(1,2,3,4) then doAction = true end
  end


  -- MOUSE AND TOUCH: these activate immediately
  if love.mouse.isDown(1) then
    triggerClick(love.mouse.getPosition())
	end

  local touches = love.touch.getTouches()
  for i, id in ipairs(touches) do
    triggerClick(love.touch.getPosition(id))
  end

  selection = math.min(math.max(1, selection + delta), 5)
  if doAction then
    triggerAction()
  end
  flux.update(dt)
end

triggerClick = function(x,y)
  if (math.abs(x - (screenWidth / 2)) > 300) then return end
  selection = math.floor((y - 230 + 30) / 90) + 1
  if (selection < 1) then return end
  if (selection > 5) then return end
  triggerAction()
end

triggerAction = function ()
  if (selection == 1) then
    love.event.push('gameExit')
  elseif (selection == 2) then
    toggleAudio()
  elseif (selection == 3) then
    -- gamepad : trigger another screen/mode. Enable, up,down,left,right,trigger,escape
  elseif (selection == 4) then
    -- keyboard : same as gamepad, but can't disable
  elseif (selection == 5) then
    -- ??? Maybe revert to defaults?
  end
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

  local height = 140
  local xpos = screenWidth / 2
  love.graphics.setColor(255, 255, 255, 255)

  local audioState = "on"
  if love.audio.isMuted() then audioState = "off" end

  local strs = {" Back ", " Sounds (currently "..audioState..") ",
    " Gamepad setup ", " Keyboard setup ", " ??? "}
  strs[selection] = "[" .. strs[selection] .. "]"

  for i=1,5 do
    height = height + 90
    centreSmallString(strs[i], xpos, height, 2)
  end
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

toggleAudio = function()
  if love.audio.isMuted() then
    love.audio.unmute()
  else
    love.audio.mute()
  end
end

return {
  Initialise = Initialise,
  Draw = Draw,
  Update = Update,
  LoadState = LoadState,
  Reset = Reset
}
