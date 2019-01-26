----------------------------------------------------------------------
--
-- Export image to C64 high resolution bitmap format
-- either as pure data or with an added viewer as a .prg
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

if spr.width~=320 or spr.height ~= 200 then
  app.alert("The sprite dimensions should be 320x200!")
  return false
end

if spr.colorMode~= ColorMode.INDEXED then
  app.alert("The sprite should use indexed color mode!")
  return false
end


-- TODO: checks: number of colors?, errors!, find bg color autamtically

-- default new file is the same as the aseprite without the extension
local newfilename = string.gsub(spr.filename, ".aseprite", "")

-- Build export dialog
local d =
  Dialog("Export C64 Hires Bitmap format")
  :entry {id = "fname", label = "Save as:", text = newfilename, focus = true}
  :entry {id = "loadaddress", label = "Load at: $", text = "2000"}
  :radio {id = "hed", text = "hed"}:radio {id = "prg", text = "PRG", selected = true}
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
local screenRAM = {}

for cy = 0, 24 do
  for cx = 0, 39 do
    local cellBGCol = nil
    local cellFGCol = nil

    for ccy = 0, 7 do
      local row = ""
      for ccx = 0, 7 do
        local col = img:getPixel(cx * 8 + ccx, cy * 8 + ccy)

        if cellBGCol==nil then
          cellBGCol = col
        elseif col~=cellBGCol and cellFGCol == nil then
          cellFGCol = col
        end

        if cellBGCol==col then
          row=row.."0"
        else
          row=row.."1"
        end

      end

      table.insert(bitmap, tonumber(row, 2))
    end

    if cellBGCol == nil then cellBGCol=0 end
    if cellFGCol == nil then cellFGCol=0 end
    table.insert(screenRAM, cellFGCol*16+cellBGCol)

  end
end


local outfname = data.fname
if data.prg == true then
  outfname = outfname .. ".prg"
else
  outfname = outfname .. ".hed"
end

local out = io.open(outfname, "wb")

-- if the format is prg, read the viewer and append the data to that
if data.prg == true then
  local inprg = io.open(script_path() .. "hiresview.prg", "rb")
  local viewerbin = inprg:read("*all")
  out:write(viewerbin)
end

-- Write load address (from the dialog)
local secondhalf = tonumber(string.sub(data.loadaddress, 3,4),16)
local firsthalf = tonumber(string.sub(data.loadaddress, 1,2),16)
out:write(string.char(secondhalf, firsthalf))

out:write(string.char(table.unpack(bitmap)))
-- pad memory
local pad = {}
for i=1,192 do pad[i] = 0 end
out:write(string.char(table.unpack(pad)))
out:write(string.char(table.unpack(screenRAM)))
out:close()

-- FIXME: Not working for some reason...
-- the os command is ok (checked in the terminal), aseprite asks for permission to run it, but nothing happens afterwards
-- aseprite bug? or some kind of os level permission thing?

-- if data.prg == true then
--   local crunchedfname = string.gsub(outfname, "[.]", ".c.")
--   local term, status, num = os.execute("exomizer sfx sys "..outfname.." -o "..crunchedfname)
-- end
