function love.conf(t)
  t.version = "11.2"  -- The LÖVE version this game was built with

  -- Same resolution as my phone. Independence later!
  t.window.width = 1312
  t.window.height = 720

  t.accelerometerjoystick = false

  t.window.title = "Survivor"
  t.window.borderless = true
  t.window.fullscreen = false
  --t.console = true
end
