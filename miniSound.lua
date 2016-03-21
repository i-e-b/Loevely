-- A minimalist sound manager to make playing sounds easier without adding a whole library
-- Handles counted loops with delays


do
  -- will hold the currently playing sources
  local sources = {}

  -- check for sources that finished playing and remove them
  -- add to love.update
  function love.audio.update(dt)
    local remove = {}
    for _,s in pairs(sources) do
      if (s.t) then
        s.t = s.t - dt
        if (s.t < 0) and (s.lc > 0) then
          love.audio.loop(s.src,s.lc,s.d)
        end
      elseif s.src:isStopped() then
        remove[#remove + 1] = s
      end
    end

    for i,s in ipairs(remove) do
      sources[s] = nil
    end
  end

  -- overwrite love.audio.play to create and register source if needed
  local play = love.audio.play
  function love.audio.play(what, how, loop)
    local src = what
    if type(what) ~= "userdata" or not what:typeOf("Source") then
      src = love.audio.newSource(what, how)
      src:setLooping(loop or false)
    end

    play(src)
    sources[src] = {src=src, lc=0, t=0}
    return src
  end

  -- rewind and play the source.
  -- useful for quickly repeated blips
  function love.audio.replay(src)
    love.audio.rewind(src)
    play(src)
  end

  function love.audio.loop(src, howMany, delay)
    play(src)
    delay = delay or 0
    sources[src] = {src=src, lc=(howMany-1), d=delay, t=delay}
    return src
  end

  -- stops a source
  local stop = love.audio.stop
  function love.audio.stop(src)
    if not src then return end
    stop(src)
    sources[src] = nil
  end
end
