--[[
  Pause screen to allow exit / resume
]]

local assets -- local copy of game-wide assets
local screenWidth, screenHeight
local selected = 'exit'

function Initialise(coreAssets)
  assets = coreAssets
  screenWidth, screenHeight = love.graphics.getDimensions()
end

function Update(dt, keyDownCount, gamepad)
  -- TODO: scan keys, pad, mouse, touch. Either exit or resume
  -- This should probably fire off an event to kick the main module
  -- to switch states
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
      love.event.push('quit') -- Quit the game.
    else
      love.event.push('gameResume') -- kick up a resume event
    end
  end
end

function Draw()
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

function centreBigString(str, x, y, scale)
  scale = scale or 1
  local w = scale * assets.bigfont:getWidth(str) / 2
  love.graphics.print(str, math.floor(x - w), math.floor(y - (scale * 13.5)), 0, scale)
end


return {
  Initialise = Initialise,
  Draw = Draw,
  Update = Update
}
