local anim8 = require "anim8" -- character animations
local flux = require "flux"   -- movement tweening. Modified from standard

local state_game = require "state_game"
local state_levelEnd = require "state_levelEnd"

local levelNames = {"ztown.tmx", "hospital.tmx", "gauntlet.tmx", "theRing.tmx"}

local screenWidth, screenHeight

local assets = {smallfont, bigfont, creepSheet} -- UI animations

local CurrentGlobalState = nil
local GameState = nil -- the current game. "New Game" resets, "Load" sets up

local keyDownCount = 0 -- helper for skip scenes

-- Load non dynamic values
function love.load()
  love.window.fullscreen = (love.system.getOS() == "Android")


  assets.creepSheet = love.graphics.newImage("assets/creeps.png")
  assets.bigfont = love.graphics.newImageFont("assets/bigfont.png", "!$'*+,-.0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZ")
  assets.smallfont = love.graphics.newImageFont("assets/smallfont.png", " abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,!?-+/():;%&`'*#=[]\"")

  assets.creepSheet:setFilter("linear", "nearest") -- pixel art scaling: linear down, nearest up
  assets.bigfont:setFilter("linear", "nearest")
  assets.smallfont:setFilter("linear", "nearest")


  state_game.Initialise(assets)
  state_levelEnd.Initialise(assets)
  GameState = state_game.CreateNewGameState()
  state_game.LoadState(levelNames[1], GameState) -- todo: level is in gamestate, and gets updated on progress
  CurrentGlobalState = state_game
end

-- Update, with frame time in fractional seconds
function love.update(dt)
  if (GameState.LevelComplete) then
    if (GameState.LevelShouldAdvance) then
      state_game.AdvanceLevel(GameState)
      state_game.LoadState(levelNames[GameState.Level], GameState)
      CurrentGlobalState = state_game
    else
      state_levelEnd.LoadState(GameState)
      CurrentGlobalState = state_levelEnd
    end
  end

  CurrentGlobalState.Update(dt, keyDownCount)
end

function love.keypressed(key, unicode)
  if k == 'escape' then
    love.event.push('quit') -- Quit the game.
  end
  keyDownCount = keyDownCount + 1
end
function love.mousepressed( x, y, button, istouch )
  keyDownCount = keyDownCount + 1
end

function love.keyreleased(key)
  keyDownCount = keyDownCount - 1
end
function love.mousereleased( x, y, button, istouch )
  keyDownCount = keyDownCount - 1
end


-- Draw a frame
function love.draw()
  CurrentGlobalState.Draw()
end
