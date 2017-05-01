--[[
  Configure screen: change gamepad mapping
]]
local flux = require "flux"   -- movement tweening. Modified from standard


local assets -- local copy of game-wide assets
local screenWidth, screenHeight
local currentGame
local readyForInput
local selection = 1
local readLatch = false

local Initialise, Update, LoadState, Draw, Reset, triggerClick, triggerAction,
rightAlignString, centreBigString, centreSmallString, toggleAudio, scanJoy

local mapVal = ""
scanJoy = function(pad)
  -- scan axes. Only works if the abs value can go past 0.8
  for i=1, pad:getAxisCount() do
    local v = pad:getAxis(i)
    if (math.abs(v) > 0.8) then
      if (v > 0.8) then
        mapVal = "a"..i.."n"
      elseif (v < -0.8) then
        mapVal = "a"..i.."p"
      end
    end
  end

  -- scan buttons
  for i=1,pad:getButtonCount( ) do
    if (pad:isDown(i)) then
      mapVal = "b"..i
    end
  end
end

Initialise = function(coreAssets)
  readyForInput = false
  assets = coreAssets
  screenWidth, screenHeight = love.graphics.getDimensions()
  Reset()
end

Reset = function()
  selection = 1
end

Update = function(dt, keyDownCount, gamepad)
  if (readLatch) then
    scanJoy(gamepad)
    if (mapVal ~= "") then
      readLatch = false
    end
  end

  if keyDownCount < 1 then readyForInput = true end
  if not readyForInput then return end
  if keyDownCount > 0 then readyForInput = false end

  local delta = 0
  -- PAD AND KEYBOARD: these have a two stage select and activate
  if love.keyboard.isDown("up") then delta = -1 end
  if love.keyboard.isDown("down") then delta = 1 end

  local doAction = love.keyboard.isDown("lctrl","return","space")

  if (gamepad) and (not readLatch) then
    -- hard-coded to allow basic navigation
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

  if (delta ~= 0) then readLatch = false end
  selection = math.min(math.max(1, selection + delta), 7)
  if doAction then
    triggerAction()
  end
  flux.update(dt)
end

triggerClick = function(x,y)
  if (math.abs(x - (screenWidth / 2)) > 300) then return end
  selection = math.floor((y - 230 + 30) / 70) + 1
  if (selection < 1) then return end
  if (selection > 7) then return end
  triggerAction()
end

triggerAction = function ()
  if (selection == 1) then
    love.event.push('runSetup') -- back
  elseif (selection == 2) then
    -- enable
    assets.enableGamepad = not assets.enableGamepad
  elseif (not readLatch) and (selection >= 3) and (selection <= 7) then
    readLatch = true
  end
end

LoadState = function(gameState)
  currentGame = gameState
end


Draw = function()
  love.graphics.setColor(255, 255, 255, 255)

  love.graphics.setFont(assets.bigfont)
  centreBigString("SURVIVOR", screenWidth / 2, 70, 3)

  love.graphics.setFont(assets.smallfont)
  love.graphics.setColor(170, 170, 170, 255)
  centreSmallString("configuration > gamepad", screenWidth / 2, 120, 2)

  local height = 140
  local xpos = screenWidth / 2
  love.graphics.setColor(255, 255, 255, 255)

  local padState = "disabled"
  if assets.enableGamepad then padState = "enabled" end

  local strs = {" Back ", " Enable? (currently "..padState..") ",
    " Up ", " Down ", " Left ", " Right ", " Action ("..mapVal..") "}
  strs[selection] = "[" .. strs[selection] .. "]"

  for i=1,7 do
    height = height + 70
    if (readLatch and selection == i) then
      love.graphics.setColor(255, 100, 100, 255)
    else
      love.graphics.setColor(255, 255, 255, 255)
    end
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

return {
  Initialise = Initialise,
  Draw = Draw,
  Update = Update,
  LoadState = LoadState,
  Reset = Reset
}
