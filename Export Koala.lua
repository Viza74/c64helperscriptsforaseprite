----------------------------------------------------------------------
--
-- Export image to C64 multicolor Koala format
-- either as pure data (.kla) or with an added viewer as a .prg
--
----------------------------------------------------------------------



----------------------------------------------------------------------
-- Funcions
----------------------------------------------------------------------

local function script_path()
  local str = debug.getinfo(2, "S").source:sub(2)
  -- TODO: test regepx on Windows
  return str:match("(.*[/\\])")
end

----------------------------------------------------------------------
-- START
----------------------------------------------------------------------

local spr = app.activeSprite
if not spr then
  app.alert("There is no sprite to export")
  return
end

if spr.width~=160 or spr.height ~= 200 then
  app.alert("The sprite dimensions should be 160x200!\n(Suggestion: set the pixel aspect ratio to 2:1!)")
  return false
end

if spr.colorMode~= ColorMode.INDEXED then
  app.alert("The sprite should use indexed color mode!")
  return false
end


-- TODO: checks: number of colors?, errors!, find bg color autamtically

-- defualt new file is the same as the aseprite without the extension
local newfilename = string.gsub(spr.filename, ".aseprite", "")

-- Build export dialog
local d =
  Dialog("Export C64 Koala format")
  :entry {id = "fname", label = "Save as:", text = newfilename, focus = true}
  :entry {id = "loadaddress", label = "Load at: $", text = "6000"}
  :color {id = "bgCol", label = "BG color:", color = Color(0)}
  :radio {id = "koala", text = "Koala"}:radio {id = "prg", text = "PRG", selected = true}
  :button {id = "ok", text = "&OK", focus = true}
  :button {text = "&Cancel"}:show()

local data = d.data
if not data.ok then
  return
end

-- Validate load address
if string.len(data.loadaddress)~=4 or not string.match( data.loadaddress , "[0123456789aAbBcCdDeEfF]" ) then
  app.alert("Wrongly formatted load address: should be 4 character long hexadecimal number.")
  return
end

-- turn off debug layers before grabbing the current image
for _, layer in ipairs(spr.layers) do
  if layer.name == "Errormap" or layer.name == "Oppmap" then
    layer.isVisible=false
  end
end
app.refresh()

-- Get image from the active frame of the active sprite
local img = Image(spr.spec)
img:drawSprite(spr, app.activeFrame)

local bitmap = {}
-- temp table for colors -> 1:colorRam, 2:screenRam first half, 3:screenRam second half
local colors = {}

for cy = 0, 24 do
  for cx = 0, 39 do
    local cellCols = {}
    cellCols[0] = data.bgCol.index

    for ccy = 0, 7 do
      local row = ""
      for ccx = 0, 3 do
        local col = img:getPixel(cx * 4 + ccx, cy * 8 + ccy)

        local idx = nil
        local last = 0
        for i = 0, 3 do
          if cellCols[i] ~= nil then
            last = i
            if cellCols[i] == col then
              idx = i
            end
          end
        end

        if idx == nil then
          cellCols[last + 1] = col
          idx = last + 1
        end

        if idx == 0 then
          row = row .. "00"
        elseif idx == 1 then
          row = row .. "11"
        elseif idx == 2 then
          row = row .. "10"
        elseif idx == 3 then
          row = row .. "01"
        end
      end

      table.insert(bitmap, tonumber(row, 2))
    end

    -- pad with 0 color indeces if there are less than 4 colors in a cell
    for i = 0, 3 do
      if cellCols[i] == nil then
        cellCols[i] = 0
      end
    end
    -- remove the background color from the cell colors table
    cellCols[0] = nil
    -- store cell colors in the temp colors table
    table.insert(colors, cellCols)

  end
end

-- TODO: Check if everything is ok - #bitmap should be 8000, #colors should be 1000
-- is that enough?
-- print(#bitmap, #colors)

-- Build export structures
local colorRAM = {}
local screenRAM = {}

for i = 1, 1000 do
  -- the first value from colors goes to the color ram
  colorRAM[i] = colors[i][1]
  -- the sceond and third forms a byte, and goes to the screen ram
  screenRAM[i] = colors[i][2] + colors[i][3] * 16
end

local outfname = data.fname
if data.prg == true then
  outfname = outfname .. ".prg"
else
  outfname = outfname .. ".kla"
end

local out = io.open(outfname, "wb")

-- if the format is prg, read the viewer and append the data to that
if data.prg == true then
  local inprg = io.open(script_path() .. "koalaview.prg", "rb")
  local viewerbin = inprg:read("*all")
  out:write(viewerbin)
end

-- Write load address
if data.prg == true then
  -- ignore the dialog setting, the viewer expects the koala at 0x6000
  out:write(string.char(00, 0x60))
else
  -- Use the address from the dialog
  local secondhalf = tonumber(string.sub(data.loadaddress, 3,4),16)
  local firsthalf = tonumber(string.sub(data.loadaddress, 1,2),16)
  print(secondhalf,firsthalf)
  out:write(string.char(secondhalf, firsthalf))
  -- out:write(string.char(00, 0x60))
end
out:write(string.char(table.unpack(bitmap)))
out:write(string.char(table.unpack(screenRAM)))
out:write(string.char(table.unpack(colorRAM)))
out:write(string.char(data.bgCol.index))
out:close()

-- FIXME: Not working for some reason...
-- the os command is ok (checked in the terminal), aseprite asks for permission to run it, but nothing happens afterwards
-- aseprite bug? or some kind of os level permission thing?

-- if data.prg == true then
--   local crunchedfname = string.gsub(outfname, "[.]", ".c.")
--   local term, status, num = os.execute("exomizer sfx sys "..outfname.." -o "..crunchedfname)
-- end
