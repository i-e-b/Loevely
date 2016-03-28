--[[
  Pause screen to allow exit / resume
]]

local assets -- local copy of game-wide assets
local screenWidth, screenHeight
local selected = 'resume'
local readyForInput = false

local Initialise,Update,triggerClick,Draw,centreBigString, Reset

Initialise = function(coreAssets)
  assets = coreAssets
  screenWidth, screenHeight = love.graphics.getDimensions()
end

Reset = function()
  selected = 'resume'
  readyForInput = false
end

Update = function(dt, keyDownCount, gamepad)
  if (keyDownCount < 1) then readyForInput = true end
  if (not readyForInput) then return end
  -- Scan keys, pad, mouse, touch. Either exit or resume
  -- This should probably fire off an event to kick the main module
  -- to switch states

  -- PAD AND KEYBOARD: these have a two stage select and activate
  if love.keyboard.isDown("up") then
    selected = 'exit'
  elseif love.keyboard.isDown("down") then
    selected = 'resume'
  end

  local doAction = love.keyboard.isDown("lctrl","return","space")

  if (gamepad) then
    -- currently hard-coded to my own game pad
    -- TODO: config screen should be able to set this
    local dy = gamepad:getAxis(2)
    if dy == 1 then selected = 'resume' end
    if dy == -1 then selected = 'exit' end
    if gamepad:isDown(1,2,3,4) then doAction = true end
  end

  if doAction then
    if selected == 'exit' then
      love.event.push('gameExit') -- the handlers are defined in main.lua
    else
      love.event.push('gameResume')
    end
  end

  -- MOUSE AND TOUCH: these activate immediately
  if love.mouse.isDown(1) then
    triggerClick(love.mouse.getPosition())
	end

  local touches = love.touch.getTouches()
  for i, id in ipairs(touches) do
    triggerClick(love.touch.getPosition(id))
  end
end

-- A simple top half = exit, bottom half is resume; then box in a bit
triggerClick = function(x,y)
  if (math.abs(x - (screenWidth / 2)) > 300) then return end
  if (math.abs(y - (screenHeight / 2)) > 200) then return end
  if (y + 30 < (screenHeight / 2)) then
    love.event.push('gameExit') -- the handlers are defined in main.lua
  else
    love.event.push('gameResume')
  end
end

Draw = function()
  love.graphics.setColor(255, 255, 255, 255)

  love.graphics.setFont(assets.bigfont)
  centreBigString("* PAUSED *", screenWidth / 2, 70, 2)

  local exitMsg, resumeMsg
  if selected == 'exit' then
    exitMsg = "#EXIT"
    resumeMsg = " RESUME"
  else
    exitMsg = " EXIT"
    resumeMsg = "#RESUME"
  end

  local height = math.floor(screenHeight / 3)
  local left = math.floor((screenWidth / 2) - (assets.bigfont:getWidth(" PAUSED ")))

  love.graphics.print(exitMsg, left, height, 0, 2)

  height = height + 120
  love.graphics.print(resumeMsg, left, height, 0, 2)
end

centreBigString = function(str, x, y, scale)
  scale = scale or 1
  local w = scale * assets.bigfont:getWidth(str) / 2
  love.graphics.print(str, math.floor(x - w), math.floor(y - (scale * 13.5)), 0, scale)
end


return {
  Initialise = Initialise,
  Draw = Draw,
  Update = Update,
  Reset = Reset
}
