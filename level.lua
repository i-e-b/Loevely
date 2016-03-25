-- very basic level loader
-- it is fragile and specialised to this game
local xml = require "xml"
local b64 = require "b64"

-- levels can have 3 layers: 'bg', 'fg' and 'shade'
-- 'bg' is required, others are optional.
-- 'bg' and 'fg' are hit detected, and are drawn in rows to correctly
-- display with the objects and characters
-- Shade is for overlay effects and is not hit detected or drawn in rows

local drawBgRow, drawFgRow, moveMap, safePass, posToRow, isPassable,
      tileIndex, listCreeps, setupMap, setupTileset, internalUpdateTilesetBatch,
      updateTilesetBatch, readSafehouses, readInfoFlash, readTutorialFlag,
      readWarps, wappend, load

drawBgRow = function(row, level, offsets, bloodTint)
  bloodTint = bloodTint or 255
  love.graphics.setColor(255, bloodTint, bloodTint, 255)
  love.graphics.draw(level.bgBatch[row],
      math.floor(offsets.x - level.zoom * (level.mapX % 1) * level.tiles.size),
      math.floor(offsets.y - level.zoom * (level.mapY % 1) * level.tiles.size),
      0, level.zoom, level.zoom)
end

drawFgRow = function(row, level, offsets, bloodTint)
  if not level.fgBatch[row] then return end
  bloodTint = bloodTint or 255
  love.graphics.setColor(255, bloodTint, bloodTint, 255)
  love.graphics.draw(level.fgBatch[row],
      math.floor(offsets.x - level.zoom * (level.mapX % 1) * level.tiles.size),
      math.floor(offsets.y - level.zoom * (level.mapY % 1) * level.tiles.size),
      0, level.zoom, level.zoom)
end

-- central function for moving the map by whole tiles
-- input the map-wide coords in 'offsets', this gets updated as tiles
-- get swapped in and out
moveMap = function(level, targetX, targetY, offsets)
  local oldMapX = level.mapX
  local oldMapY = level.mapY

  local tzs = level.tiles.size*level.zoom

  -- translate graphics position to tile position
  local newX = math.floor(-targetX / tzs)
  local newY = math.floor(-targetY / tzs)

  -- pin translated position to legal values
  level.mapX = math.max(math.min(newX, 1+level.width - level.tiles.DisplayWidth), 1)
  level.mapY = math.max(math.min(newY, 1+level.height - level.tiles.DisplayHeight), 1)

  -- pixel offsets (fractional part of tile offset)
  offsets.x = targetX + (level.mapX * tzs)
  offsets.y = targetY + (level.mapY * tzs)

  -- if we actually moved, update the sprite batches
  -- to swap tiles in and out as needed
  if math.floor(level.mapX) ~= math.floor(oldMapX) or math.floor(level.mapY) ~= math.floor(oldMapY) then
    updateTilesetBatch(level)
  end
end

safePass = function(p, m, x, y)
  if (not m[x]) then return false end
  if (not m[x][y]) then return false end
  return p[m[x][y]]
end

-- given map tile coords, return the draw row it's on (can be off-screen)
posToRow = function(pos, level)
  return (math.ceil(pos.y) - level.mapY) + 2
end

isPassable = function(level, pos, dx, dy)
  local x = pos.x + dx
  local y = pos.y + dy + 1

  -- check bounds
  if (x<1 or y<1) then return false end
  if (x > level.width) or (y > level.height) then return false end

  -- for bg, check the target block
  if not safePass(level.passable,level.bg,x,y) then return false end

  -- for fg, if it blocks, you can go into it with  dy=1 or 0
  --         but you can only leave it with dy=-1 or 0
  if (dy == 0) then return true end
  if (dy == -1) and (safePass(level.passable,level.fg,pos.x,pos.y)) then return true end
  if (dy == 1) and (safePass(level.passable,level.fg,pos.x,pos.y+1)) then return true end
  return false
end

tileIndex = function(raw, tileOffset)
  local bz = (tileOffset * 4) + 1 -- 1 based indexing is weird
  local idx = string.byte(raw, bz)
  if idx == nil then return nil end
  idx = idx + (string.byte(raw, bz+1)*256)
  idx = idx + (string.byte(raw, bz+2)*65536)
  --idx = idx + (string.byte(raw, bz+3)*16777216) -- skipping the highest byte, as it has flags we don't interpret
  return idx
end

listCreeps = function(level, creepList, byteData)
  if (not byteData) then return end
  local mapWidth = level.width
  local mapHeight = level.height
  local idx

  for x=0,mapWidth do
    for y=0,mapHeight do
      idx = tileIndex(byteData, (y*mapWidth)+x)
      if (idx and idx > 0) then
        table.insert(creepList, {x=x, y=y, type=0+idx})
      end
    end
  end
end

setupMap = function(level, map, byteData)
  if (not byteData) then return end
  local mapWidth = level.width
  local mapHeight = level.height

  for x=0,mapWidth do
    map[x+1] = {}
    for y=0,mapHeight do
      map[x+1][y+1] = tileIndex(byteData, (y*mapWidth)+x)
    end
  end
end

setupTileset = function(level, imageName, tileSize, tilesWide, tilesTall, screenWidth, screenHeight)
  level.mapX = 1
  level.mapY = 1
  level.zoom = 4

  level.tiles.size = 0+tileSize
  level.tiles.DisplayWidth = math.ceil(screenWidth / (tileSize*level.zoom)) + 3
  level.tiles.DisplayHeight = math.ceil(screenHeight / (tileSize*level.zoom)) + 2

  level.rowsToDraw = level.tiles.DisplayHeight

  level.tiles.image = love.graphics.newImage("assets/"..imageName)
  level.tiles.image:setFilter("linear", "nearest")

  local imgWidth = level.tiles.image:getWidth()
  local imgHeight = level.tiles.image:getHeight()

  local tilesAcross = math.floor(imgWidth / tileSize) - 1
  local tilesDown = math.floor(imgHeight / tileSize) - 1

  level.width = 0+tilesWide
  level.height = 0+tilesTall

  level.tiles.quads = {}

  level.passable[0] = true -- unassigned tiles
  for y=0,tilesDown do
    for x=0,tilesAcross do
      level.passable[(y*tileSize)+x+1] = y > 5 -- hard coded passability
      level.tiles.quads[(y*tileSize)+x+1] =
        love.graphics.newQuad(
          x * tileSize, y * tileSize, tileSize, tileSize, imgWidth, imgHeight
        )
    end
  end

  -- hard coded passability. Todo: find a *nice* way to do this from the map file
  -- or load in from a *.lua file named same as tileset?
  for i,n in ipairs({18,20,36,39,40,41,64,101}) do level.passable[n] = true end
  for i,n in ipairs({
    110,111,112,126,127,128,158,159,206,207,222,223,224,235,236,237
  }) do
    level.passable[n] = false
  end

  level.fgBatch = {}
  level.bgBatch = {}
  for j=1,level.tiles.DisplayHeight do
    level.fgBatch[j] = love.graphics.newSpriteBatch(level.tiles.image, level.tiles.DisplayWidth)
    level.bgBatch[j] = love.graphics.newSpriteBatch(level.tiles.image, level.tiles.DisplayWidth)
  end
end

internalUpdateTilesetBatch = function(level, batch, map)
  local mw = math.min(level.width,  level.tiles.DisplayWidth)
  local mh = math.min(level.height, level.tiles.DisplayHeight)
  local q,mx,my

  for y=0, mh-1 do
    batch[y+1]:clear()
    for x=0, mw-1 do
      repeat -- for 'skip' break
        mx = map[x+math.floor(level.mapX)]
        if (mx == nil) then break end
        my = mx[y+math.floor(level.mapY)]
        if (my == nil) then break end
        q = level.tiles.quads[my]
        if (q ~= nil) then
          batch[y+1]:add(q, x * level.tiles.size, y * level.tiles.size)
        end
      until true -- for 'skip' break
    end
    batch[y+1]:flush()
  end
end

updateTilesetBatch = function(level)
  internalUpdateTilesetBatch(level, level.bgBatch, level.bg)
  internalUpdateTilesetBatch(level, level.fgBatch, level.fg)
end

readSafehouses = function(level, xmlNode)
  for i,subXmlNode in pairs(xmlNode.ChildNodes) do
    if (subXmlNode.Attributes.name == "safe") then
      local spec = subXmlNode.Attributes.value
      for x1,y1 in string.gmatch(spec, "(%w+),(%w+)") do
        table.insert(level.safeHouses, {x=x1+1,y=y1, followedBy={}, speed=4 })
      end
    end
  end
end

readInfoFlash = function(level, xmlNode)
  for i,subXmlNode in pairs(xmlNode.ChildNodes) do
    if (subXmlNode.Attributes.name == "info") then
      local spec = subXmlNode.Attributes.value
      for x1,y1,text in string.gmatch(spec, "(%d+),(%d+),([^;]+)") do
        table.insert(level.infoFlash, {x=x1+1,y=0+y1, text=text:gsub("\\n","\n") })
      end
    end
  end
end

readTutorialFlag = function(level, xmlNode)
  for i,subXmlNode in pairs(xmlNode.ChildNodes) do
    if (subXmlNode.Attributes.name == "tutorial") then
      level.isTutorial = true
    end
  end
end

readWarps = function(level, xmlNode)
  for i,subXmlNode in pairs(xmlNode.ChildNodes) do
    if (subXmlNode.Attributes.name == "warp") then
      local spec = subXmlNode.Attributes.value
      for x1,y1,x2,y2 in string.gmatch(spec, "(%w+),(%w+):(%w+),(%w+)") do
        wappend(level.warps, x1,y1,x2,y2)
        wappend(level.warps, x2,y2,x1,y1)
      end
    end
  end
end
wappend = function(arry, x1,y1,x2,y2)
  if not arry[x1+1] then arry[x1+1] = {} end
  arry[x1+1][0+y1] = {x=x2+1, y=0+y2}
end

load = function(filename, screenWidth, screenHeight)
  local xmlTest, xmlError = xml:ParseXmlFile(filename)
  if (xmlError ~= "ok") then error(xmlError) end
  local lvl = {
    bg={}, fg={}, shade={}, placement={},
    tiles={}, passable={}, warps={}, safeHouses={},
    infoFlash={}, isTutorial=false
  }

  for i,xmlNode in pairs(xmlTest.ChildNodes) do
    if (xmlNode.Name == "tileset") then  -- read in image name, load the image
      setupTileset(lvl,
        xmlNode.ChildNodes[1].Attributes.source,
        xmlTest.Attributes.tilewidth,
        xmlTest.Attributes.width, xmlTest.Attributes.height,
        screenWidth, screenHeight
      )

    elseif (xmlNode.Name == "properties") then  -- read warp zones
      readWarps(lvl, xmlNode)
      readSafehouses(lvl, xmlNode)
      readInfoFlash(lvl, xmlNode)
      readTutorialFlag(lvl, xmlNode)
    elseif (xmlNode.Name == "layer") then  -- decode tile data into a map table
      local data

      for i,subXmlNode in pairs(xmlNode.ChildNodes) do
        if (subXmlNode.Name == "data" and subXmlNode.Value) then -- it's a tile array
          if (subXmlNode.Attributes.encoding ~= "base64" or subXmlNode.Attributes.compression ~= "zlib") then
            error("Layer format must be base64 and zlib compressed")
          end
          data = love.math.decompress(b64.decode(subXmlNode.Value), "zlib" )
        end
      end

      if xmlNode.Attributes.name == "bg" then
        setupMap(lvl, lvl.bg, data)
      elseif xmlNode.Attributes.name == "fg" then
        setupMap(lvl, lvl.fg, data)
      elseif xmlNode.Attributes.name == "placement" then
        listCreeps(lvl, lvl.placement, data)
      end

    end
  end

  updateTilesetBatch(lvl)
  return lvl
end

return {
  load = load,
  drawBgRow = drawBgRow,
  drawFgRow = drawFgRow,
  moveMap = moveMap,
  isPassable = isPassable,
  posToRow = posToRow
}
