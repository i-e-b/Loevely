local anim8 = require "anim8" -- character animations
local flux = require "flux"   -- movement tweening. Modified from standard

local state_game = require "state_game"

local levelNames = {"ztown.tmx", "hospital.tmx", "gauntlet.tmx"}

local screenWidth, screenHeight

local assets = {smallfont, bigfont, creepSheet} -- UI animations

local CurrentGlobalState = nil
local GameState = nil -- the current game. "New Game" resets, "Load" sets up

-- Load non dynamic values
function love.load()
  love.window.fullscreen = (love.system.getOS() == "Android")

  assets.smallfont = love.graphics.newImageFont("assets/smallfont.png", " abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,!?-+/():;%&`'*#=[]\"")
  assets.smallfont:setFilter("linear", "nearest")
  assets.bigfont = love.graphics.newImageFont("assets/bigfont.png", "!$'*+,-.0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZ")
  assets.bigfont:setFilter("linear", "nearest")

  assets.creepSheet = love.graphics.newImage("assets/creeps.png")
  assets.creepSheet:setFilter("linear", "nearest") -- pixel art scaling: linear down, nearest up


  state_game.Initialise(assets)
  GameState = state_game.CreateNewGameState()
  state_game.LoadState(levelNames[1], GameState) -- todo: level is in gamestate, and gets updated on progress
  CurrentGlobalState = state_game
end

-- handle universal input (pause / exit to menu / immediate exit / etc)
function love.keypressed(k)
	if k == 'escape' then
		love.event.push('quit') -- Quit the game.
  end
end

-- Update, with frame time in fractional seconds
function love.update(dt)
  if (GameState.LevelComplete) then
    GameState.LevelComplete = false
    GameState.Level = GameState.Level + 1

    state_game.LoadState(levelNames[GameState.Level], GameState)
  end

  CurrentGlobalState.Update(dt)
end

-- Draw a frame
function love.draw()
  CurrentGlobalState.Draw()
end
