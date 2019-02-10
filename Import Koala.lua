----------------------------------------------------------------------
--
-- Import C64 Koala format image
--
----------------------------------------------------------------------

-- Build import dialog
local d =
  Dialog("Import C64 Koala format")
  :label {text = "Please enter a file name below:"}
  :entry {id = "fname", text = "", focus = true}
  :button {id = "ok", text = "&OK"}
  :button {text = "&Cancel"}
  :show()

local data = d.data
if not data.ok then
  return
end

if data.fname == "" then
  app.alert {title="Error", text="No filename was given."}
  return
end

--fname = "/Users/viza/VizaDocs/C64/gfx/sentinels.kla"
local infile = io.open(data.fname, "rb")
if infile == nil then
  app.alert {title="Error", text="Can't open file " .. data.fname .. " for import."}
  return
end

local kla = infile:read("*all")
infile:close()

if #kla ~= 10003 then
  app.alert {title="Error", text="The kla file should be exactly 10003 bytes in size, the opened file is " .. #kla}
  return
end

-- Create a new sprite to load into
local newSpr = Sprite(160, 200, ColorMode.INDEXED)

-- Set up C64 palette (using the colors from the built-in C64 palette)
local pal = newSpr.palettes[1]
pal:resize(16)
pal:setColor(00, Color {r = 0, g = 0, b = 0})
pal:setColor(01, Color {r = 255, g = 255, b = 255})
pal:setColor(02, Color {r = 136, g = 57, b = 50})
pal:setColor(03, Color {r = 103, g = 182, b = 189})
pal:setColor(04, Color {r = 139, g = 63, b = 150})
pal:setColor(05, Color {r = 85, g = 160, b = 73})
pal:setColor(06, Color {r = 64, g = 49, b = 141})
pal:setColor(07, Color {r = 191, g = 206, b = 114})
pal:setColor(08, Color {r = 139, g = 84, b = 41})
pal:setColor(09, Color {r = 87, g = 66, b = 0})
pal:setColor(10, Color {r = 184, g = 105, b = 98})
pal:setColor(11, Color {r = 80, g = 80, b = 80})
pal:setColor(12, Color {r = 120, g = 120, b = 120})
pal:setColor(13, Color {r = 148, g = 224, b = 137})
pal:setColor(14, Color {r = 120, g = 105, b = 196})
pal:setColor(15, Color {r = 159, g = 159, b = 159})

-- TODO: Set pixel aspect to double width
-- Unfortunately it seems that it is not possible to set up this from script right now :(

app.command.BackgroundFromLayer()
local img = newSpr.cels[1].image

local bgcol = string.byte(kla, 10003)

local function getColorFor(cx, cy, idx)
  local colbyteidx = 0

  if idx == 1 then
    -- screen ram bits 4-7
    colbyteidx = 8003 + cx + cy * 40
    return ((string.byte(kla, colbyteidx) & 0xF0) >> 4)
  end

  if idx == 2 then
    -- screen ram bits 0-3
    colbyteidx = 8003 + cx + cy * 40
    return (string.byte(kla, colbyteidx) & 0x0F)
  end

  if idx == 3 then
    -- color ram bits 4-7
    colbyteidx = 9003 + cx + cy * 40
    return (string.byte(kla, colbyteidx) & 0x0F)
  end

  -- background color
  return bgcol
end

for cy = 0, 24 do
  for cx = 0, 39 do

    for ccy = 0, 7 do
      -- get byte from bitmap data for current attribute cell's current row
      local bmpbyte = string.byte(kla, 3 + cy * 8 * 40 + cx * 8 + ccy)

      -- extract the four color indexes from the byte
      local x = cx * 4
      local y = cy * 8 + ccy
      -- first two bits
      img:putPixel(x  , y, getColorFor(cx, cy, (bmpbyte & 192) >> 6))
      -- second two bits
      img:putPixel(x+1, y, getColorFor(cx, cy, (bmpbyte & 48) >> 4))
      -- third two bits
      img:putPixel(x+2, y, getColorFor(cx, cy, (bmpbyte & 12) >> 2))
      -- last two bits
      img:putPixel(x+3, y, getColorFor(cx, cy, (bmpbyte & 3)))
    end

  end
end

app.refresh()
