require "miniSound"           -- audio manager
local anim8 = require "anim8" -- character animations
local flux = require "flux"   -- movement tweening. Modified from standard

local state_titleScreen = require "state_titleScreen"
local state_game = require "state_game"
local state_levelEnd = require "state_levelEnd"
local state_finalScreen = require "state_finalScreen"
local state_pause = require "state_pause"
local state_configure = require "state_configure"
local state_configureGamepad = require "state_configureGamepad"

local levelNames = {
  "tut_01.tmx", "tut_02.tmx", "tut_03.tmx", "tut_04.tmx",
  "level1.tmx",
  "ztown.tmx", "hospital.tmx", "gauntlet.tmx", "ring.tmx", "rooftops.tmx",
  "maze1.tmx", "maze2.tmx"
}

local screenWidth, screenHeight

local assets = {smallfont, bigfont, creepSheet} -- UI animations
local currentJoystick = nil

local CurrentGlobalState = nil
local GameState = nil -- the current game. "New Game" resets, "Load" sets up

local keyDownCount = 0 -- helper for skip scenes

-- Load non dynamic values
function love.load()
  love.window.fullscreen = (love.system.getOS() == "Android")

  assets.enableGamepad = true
  assets.gamepadMap = {}

  assets.creepSheet = love.graphics.newImage("assets/creeps.png")
  assets.bigfont = love.graphics.newImageFont("assets/bigfont.png", "!$#*+,-.0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZ")
  assets.smallfont = love.graphics.newImageFont("assets/smallfont.png", " abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,!?-+/():;%&`'*#=[]>")

  -- static only for small short and repeated sounds
  assets.munchSnd = love.audio.newSource("assets/munch.wav", "static")
  assets.pickupSnd = love.audio.newSource("assets/pickup.wav", "static")
  assets.shoveSnd = love.audio.newSource("assets/shove.wav", "static")
  assets.saveSnd = love.audio.newSource("assets/save.wav", "static")
  assets.walkSnd = love.audio.newSource("assets/walk.wav", "static")
  assets.coinSnd = love.audio.newSource("assets/coin.wav", "static")

  assets.creepSheet:setFilter("linear", "nearest") -- pixel art scaling: linear down, nearest up
  assets.bigfont:setFilter("linear", "nearest")
  assets.smallfont:setFilter("linear", "nearest")

  state_titleScreen.Initialise(assets)
  state_game.Initialise(assets)
  state_levelEnd.Initialise(assets)
  state_finalScreen.Initialise(assets)
  state_pause.Initialise(assets)
  state_configure.Initialise(assets)
  state_configureGamepad.Initialise(assets)

  love.handlers['gameResume'] = resumeGame
  love.handlers['gamePause'] = pauseGame
  love.handlers['gameExit'] = exitGame
  love.handlers['loadGame'] = loadGameAndSetState
  love.handlers['startTutorial'] = loadTutorial
  love.handlers['runSetup'] = runSetup
  love.handlers['runSetupGamepad'] = runSetupGamepad

  love.audio.mute()
  CurrentGlobalState = state_titleScreen
end

function runSetup()
  state_configure.Reset()
  CurrentGlobalState = state_configure
end

function runSetupGamepad()
  state_configureGamepad.Reset()
  CurrentGlobalState = state_configureGamepad
end

function loadTutorial ()
  GameState = state_game.CreateNewGameState()
  GameState.Level = 1
  state_game.LoadState(levelNames[GameState.Level], GameState)
  CurrentGlobalState = state_game
end

function loadGameAndSetState (game)
  game = game or state_game.CreateNewGameState()
  GameState = game
  state_game.LoadState(levelNames[GameState.Level], GameState)
  CurrentGlobalState = state_game
end

function resumeGame ()
  if (GameState == nil) then return end
  CurrentGlobalState = state_game
end
function pauseGame ()
  if (CurrentGlobalState ~= state_game) then return end
  state_pause.Reset()
  CurrentGlobalState = state_pause
end
function exitGame ()
  state_titleScreen.Reset()
  CurrentGlobalState = state_titleScreen
end

-- connect joysticks and gamepads
function love.joystickadded(joystick)
  currentJoystick = joystick
end

function love.joystickremoved(joystick)
  if (currentJoystick == joystick) then
    currentJoystick = nil
  end
end

-- Update, with frame time in fractional seconds
function love.update(dt)
  love.audio.update(dt)

  if (GameState and GameState.LevelComplete) then
    if (GameState.LevelShouldAdvance) then
      state_game.AdvanceLevel(GameState)
      if (levelNames[GameState.Level]) then
        state_game.LoadState(levelNames[GameState.Level], GameState)
        CurrentGlobalState = state_game
      else
        state_finalScreen.LoadState(GameState)
        CurrentGlobalState = state_finalScreen
      end
    else
      state_levelEnd.LoadState(GameState)
      CurrentGlobalState = state_levelEnd
    end
  end

  local activeStick = currentJoystick
  if (not assets.enableGamepad) then activeStick = nil end
  CurrentGlobalState.Update(dt, keyDownCount, activeStick)
end

-- Draw a frame
function love.draw()
  CurrentGlobalState.Draw()
end

function love.keypressed(key)
  keyDownCount = keyDownCount + 1
  if key == 'escape' then pauseGame() end
end
function love.joystickpressed(joystick,button)
  keyDownCount = keyDownCount + 1
  if button == 10 then pauseGame() end
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
function love.joystickreleased(joystick,button)
  keyDownCount = keyDownCount - 1
end
