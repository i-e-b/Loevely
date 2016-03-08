
local xml = require "xml"
local b64 = require "b64"
local dumper = require "dumper"

function load(filename, screenWidth, screenHeight)
  local xmlTest, xmlError = xml:ParseXmlFile(filename)
  if (xmlError ~= "ok") then error(xmlError) end
  local lvl = {bg={}, fg={}, tiles={}}
  for i,xmlNode in pairs(xmlTest.ChildNodes) do
    if (xmlNode.Name == "tileset") then
      -- read in image name, load the image
      setupTileset(lvl,
          xmlNode.ChildNodes[1].Attributes.source,
          xmlTest.Attributes.tilewidth,
          xmlTest.Attributes.width, xmlTest.Attributes.height,
          screenWidth, screenHeight)

    elseif (xmlNode.Name == "properties") then
      -- read warp zones
    elseif (xmlNode.Name == "layer") then
      -- decode tile data into a map table
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

function drawBg(level, offsets)
  love.graphics.setColor(255, 255, 255, 255)
  love.graphics.draw(level.bgBatch,
     math.floor(offsets.x - level.zoomX * (level.mapX % 1) * level.tiles.size),
     math.floor(offsets.y - level.zoomY * (level.mapY % 1) * level.tiles.size),
    0, level.zoomX, level.zoomY)
end

function drawFg(level, offsets)
  love.graphics.setColor(255, 255, 255, 255)
  love.graphics.draw(level.fgBatch,
     math.floor(offsets.x - level.zoomX * (level.mapX % 1) * level.tiles.size),
     math.floor(offsets.y - level.zoomY * (level.mapY % 1) * level.tiles.size),
    0, level.zoomX, level.zoomY)
end

-- central function for moving the map by whole tiles
function moveMap(level, dx, dy, m_offset)
  local oldMapX = level.mapX
  local oldMapY = level.mapY
  level.mapX = math.max(math.min(level.mapX + dx, level.width - level.tiles.DisplayWidth), 1)
  level.mapY = math.max(math.min(level.mapY + dy, level.height - level.tiles.DisplayHeight), 1)
  if level.mapX ~= oldMapX then m_offset.x = m_offset.x + (dx * level.tiles.size * level.zoomX) end
  if level.mapY ~= oldMapY then m_offset.y = m_offset.y + (dy * level.tiles.size * level.zoomY) end
  -- only update if we actually moved
  if math.floor(level.mapX) ~= math.floor(oldMapX) or math.floor(level.mapY) ~= math.floor(oldMapY) then
    updateTilesetBatch(level)
  end
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
  level.zoomX = 1
  level.zoomY = 1

  level.tiles.size = tileSize
  level.tiles.DisplayWidth = math.ceil(screenWidth / (tileSize*level.zoomX)) + 3
  level.tiles.DisplayHeight = math.ceil(screenHeight / (tileSize*level.zoomY)) + 2

  level.tiles.image = love.graphics.newImage(imageName)
  level.tiles.image:setFilter("nearest", "nearest")

  local imgWidth = level.tiles.image:getWidth()
  local imgHeight = level.tiles.image:getHeight()

  local tilesAcross = math.floor(imgWidth / tileSize) - 1
  local tilesDown = math.floor(imgHeight / tileSize) - 1

  level.width = tilesWide
  level.height = tilesTall

  level.tiles.quads = {}
  for x=0,tilesAcross do
    for y=0,tilesDown do
      level.tiles.quads[(y*tileSize)+x+1] =
        love.graphics.newQuad(
          x * tileSize, y * tileSize, tileSize, tileSize, imgWidth, imgHeight
        )
    end
  end
  level.fgBatch = love.graphics.newSpriteBatch(level.tiles.image,(level.tiles.DisplayWidth * level.tiles.DisplayHeight))
  level.bgBatch = love.graphics.newSpriteBatch(level.tiles.image,(level.tiles.DisplayWidth * level.tiles.DisplayHeight))
end

function updateTilesetBatch(level)
  internalUpdateTilesetBatch(level, level.bgBatch, level.bg)
  internalUpdateTilesetBatch(level, level.fgBatch, level.fg)
end

function internalUpdateTilesetBatch(level, batch, map)
  batch:clear()
  local mw = math.min(level.width,  level.tiles.DisplayWidth)
  local mh = math.min(level.height, level.tiles.DisplayHeight)
  local q,mx,my

  for x=0, mw-1 do
    for y=0, mh-1 do
      repeat -- for 'skip' break
        mx = map[x+math.floor(level.mapX)]
        if (mx == nil) then break end
        my = mx[y+math.floor(level.mapY)]
        if (my == nil) then break end
        q = level.tiles.quads[my]
        if (q ~= nil) then
          batch:add(q, x * level.tiles.size, y * level.tiles.size)
        end
      until true -- for 'skip' break
    end
  end
  batch:flush()
end

local export = {
  load = load,
  drawBg = drawBg,
  drawFg = drawFg,
  moveMap = moveMap
}
return export
