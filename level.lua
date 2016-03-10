-- very basic level loader
-- it is fragile and specialised to this game
local xml = require "xml"
local b64 = require "b64"

function load(filename, screenWidth, screenHeight)
  local xmlTest, xmlError = xml:ParseXmlFile(filename)
  if (xmlError ~= "ok") then error(xmlError) end
  local lvl = {bg={}, fg={}, tiles={}, passable={}, warps={}}

  for i,xmlNode in pairs(xmlTest.ChildNodes) do
    if (xmlNode.Name == "tileset") then  -- read in image name, load the image
      setupTileset(lvl,
          xmlNode.ChildNodes[1].Attributes.source,
          xmlTest.Attributes.tilewidth,
          xmlTest.Attributes.width, xmlTest.Attributes.height,
          screenWidth, screenHeight)

    elseif (xmlNode.Name == "properties") then  -- read warp zones
      readWarps(lvl, xmlNode)

    elseif (xmlNode.Name == "layer") then  -- decode tile data into a map table
      local target
      if xmlNode.Attributes.name == "bg" then target = lvl.bg else target = lvl.fg end

      for i,subXmlNode in pairs(xmlNode.ChildNodes) do
        if (subXmlNode.Name == "data" and subXmlNode.Value) then -- it's a tile array
          if (subXmlNode.Attributes.encoding ~= "base64"
            or subXmlNode.Attributes.compression ~= "zlib") then
              error("Layer format must be base64 and zlib compressed")
          end

          setupMap(lvl, target, subXmlNode.Value)
        end
      end
    end
  end

  updateTilesetBatch(lvl)
  return lvl
end

function drawBgRow(row, level, offsets)
  love.graphics.setColor(255, 255, 255, 255)
  love.graphics.draw(level.bgBatch[row],
      math.floor(offsets.x - level.zoom * (level.mapX % 1) * level.tiles.size),
      math.floor(offsets.y - level.zoom * (level.mapY % 1) * level.tiles.size),
      0, level.zoom, level.zoom)
end

function drawFgRow(row, level, offsets)
  love.graphics.setColor(255, 255, 255, 255)
  love.graphics.draw(level.fgBatch[row],
      math.floor(offsets.x - level.zoom * (level.mapX % 1) * level.tiles.size),
      math.floor(offsets.y - level.zoom * (level.mapY % 1) * level.tiles.size),
      0, level.zoom, level.zoom)
end

-- central function for moving the map by whole tiles
-- input the map-wide coords in 'offsets', this gets updated as tiles
-- get swapped in and out
function moveMap(level, targetX, targetY, offsets)
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

-- given map tile coords, return the draw row it's on (can be off-screen)
function posToRow(pos, level)
  return (math.ceil(pos.y) - level.mapY) + 2
end

function isPassable(level, pos, dx, dy)
  local x = pos.x + dx
  local y = pos.y + dy + 1

  -- check bounds
  if (x<1 or y<1) then return false end
  if (x > level.width) or (y > level.height) then return false end

  -- for bg, check the target block
  if not level.passable[level.bg[x][y]] then return false end

  -- for fg, if it blocks, you can go into it with  dy=1 or 0
  --         but you can only leave it with dy=-1 or 0
  if (dy == 0) then return true end
  if (dy == -1) and (level.passable[level.fg[pos.x][pos.y]]) then return true end
  if (dy == 1) and (level.passable[level.fg[pos.x][pos.y+1]]) then return true end
  return false
end

function tileIndex(raw, tileOffset)
  local bz = (tileOffset * 4) + 1 -- 1 based indexing is weird
  local idx = string.byte(raw, bz)
  if idx == nil then return nil end
  idx = idx + (string.byte(raw, bz+1)*256)
  idx = idx + (string.byte(raw, bz+2)*65536)
  --idx = idx + (string.byte(raw, bz+3)*16777216) -- skipping the highest byte, as it has flags we don't interpret
  return idx
end

function setupMap(level, map, encodedData)
  local mapWidth = level.width
  local mapHeight = level.height

  local tileRawData = love.math.decompress(b64.decode(encodedData), "zlib" )

  for x=0,mapWidth do
    map[x+1] = {}
     for y=0,mapHeight do
      map[x+1][y+1] = tileIndex(tileRawData, (y*mapWidth)+x)
    end
  end

end

function setupTileset(level, imageName, tileSize, tilesWide, tilesTall, screenWidth, screenHeight)
  level.mapX = 1
  level.mapY = 1
  level.zoom = 4

  level.tiles.size = 0+tileSize
  level.tiles.DisplayWidth = math.ceil(screenWidth / (tileSize*level.zoom)) + 3
  level.tiles.DisplayHeight = math.ceil(screenHeight / (tileSize*level.zoom)) + 2

  level.rowsToDraw = level.tiles.DisplayHeight

  level.tiles.image = love.graphics.newImage(imageName)
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
  for i,n in ipairs({18,20,21,22,36,37,38,39,40,41,64,101}) do level.passable[n] = true end
  for i,n in ipairs({110,111,112,126,127,128,158,159,190,191,222,223}) do level.passable[n] = false end

  level.fgBatch = {}
  level.bgBatch = {}
  for j=1,level.tiles.DisplayHeight do
    level.fgBatch[j] = love.graphics.newSpriteBatch(level.tiles.image, level.tiles.DisplayWidth)
    level.bgBatch[j] = love.graphics.newSpriteBatch(level.tiles.image, level.tiles.DisplayWidth)
  end
end

function updateTilesetBatch(level)
  internalUpdateTilesetBatch(level, level.bgBatch, level.bg)
  internalUpdateTilesetBatch(level, level.fgBatch, level.fg)
end

function internalUpdateTilesetBatch(level, batch, map)
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

function readWarps(level, xmlNode)
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
function wappend(arry, x1,y1,x2,y2)
  if not arry[x1+1] then arry[x1+1] = {} end
  arry[x1+1][0+y1] = {x=x2+1, y=0+y2}
end

local export = {
  load = load,
  drawBgRow = drawBgRow,
  drawFgRow = drawFgRow,
  moveMap = moveMap,
  isPassable = isPassable,
  posToRow = posToRow
}
return export
