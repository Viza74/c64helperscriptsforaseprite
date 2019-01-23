----------------------------------------------------------------------
--
-- C64 multicolor format helpers
--
----------------------------------------------------------------------


local actLayer = nil
local bgColor = Color(0)
-- Forward declarations
local d
local buildWindow = function()
end


----------------------------------------------------------------------
-- HELPER FUNCTIONS
----------------------------------------------------------------------

local function addToSet(set, key)
  if set[key] == nil then
    set[key] = 1
  else
    set[key] = set[key]+1
  end
end

local function removeFromSet(set, key)
  set[key] = nil
end

local function setContains(set, key)
  return set[key] ~= nil
end

local function setCount(set)
  local count = 0
  for i in pairs(set) do
    count = count + 1
  end
  return count
end



local function checkPrerequesities(app)
  local spr = app.activeSprite
  if not spr then
    app.alert("There is no active sprite!")
    return false
  end

  if spr.width~=160 or spr.height ~= 200 then
    app.alert("The sprite dimensions should be 160x200!\n(Suggestion: set the pixel aspect ratio to 2:1!)")
    return false
  end

  if spr.colorMode~= ColorMode.INDEXED then
    app.alert("The sprite should use indexed color mode!")
    return false
  end

  -- TODO:
  -- colors check:
    -- check actual colors against a built in palette?
    -- just check the number of colors > 16
  -- check/create marker colors

  return true
end


local function findLayer(app, layername)
  local spr = app.activeSprite
  if not spr then
    app.alert("There is no active sprite!")
    return
  end

  for _, layer in ipairs(spr.layers) do
    if layer.name == layername then
      return layer
    end
  end

  return nil
end



----------------------------------------------------------------------
-- MAIN ACTIONS
----------------------------------------------------------------------


-- TODO: in each error cell mark the least frequent color with a different marker color
local function mapErrors(app, dlgdata, bgCol, doMarks)
  if checkPrerequesities(app)~=true then
    return
  end

  bgCol = bgCol or dlgdata.bgCol.index
  if doMarks == nil then doMarks = true end

  local numErrorCells = 0

  app.transaction(
    function()

      local spr = app.activeSprite

      -- Store active layer (so we can restore later)
      actLayer = app.activeLayer

      -- Remove previous error layer if any
      local elayer = findLayer(app, "Errormap")

      if elayer ~= nil then
        spr:deleteLayer(elayer)
      end

      -- Get image from the active frame of the active sprite
      local img = Image(spr.spec)
      img:drawSprite(spr, app.activeFrame)

      -- Create empty error image
      local errimg
      if doMarks then
        errimg = Image(spr.spec)
        errimg:clear()
      end

      for cy = 0, 25 do
        for cx = 0, 40 do
          local cellCols = {}
          for ccy = 0, 7 do
            for ccx = 0, 3 do
              local col = img:getPixel(cx * 4 + ccx, cy * 8 + ccy)
              if not setContains(cellCols, col) then
                addToSet(cellCols, col)
              end
            end
          end

          if setCount(cellCols) > 4 or (setCount(cellCols) == 4 and not setContains(cellCols, bgCol)) then
            numErrorCells = numErrorCells+1
            if doMarks then
              for ccy = 0, 7 do
                for ccx = 0, 3 do
                  errimg:putPixel(cx * 4 + ccx, cy * 8 + ccy, 17)
                end
              end
            end
          end
        end
      end

      -- add error layer to the image
      if doMarks then
        elayer = spr:newLayer()
        elayer.name = "Errormap"
        elayer.opacity = 128
        spr:newCel(elayer, app.activeFrame, errimg)
        elayer:cel(app.activeFrame).image = errimg
      end

      -- restore active layer to stored (adding the error layer selects that layer as active)
      if actLayer ~= nil then
        app.activeLayer = actLayer
      end

      app.refresh()
    end
  )
  return numErrorCells
end



-- Check image for opportunities = cells which have less than the available colors
local function mapOpportunities(app, dlgdata)
  if checkPrerequesities(app)~=true then
    return
  end

  app.transaction(
    function()

      -- Store active layer (so we can restore later)
      actLayer = app.activeLayer

      local spr = app.activeSprite

      -- Remove previous opportunity layer if any
      local opplayer = findLayer(app, "Oppmap")

      if opplayer ~= nil then
        spr:deleteLayer(opplayer)
      end

      -- Get image from the active frame of the active sprite
      local img = Image(spr.spec)
      img:drawSprite(spr, app.activeFrame)

      -- Create empty opportunity map image
      local oppimg = Image(spr.spec)
      oppimg:clear()

      for cy = 0, 25 do
        for cx = 0, 40 do
          local cellCols = {}
          for ccy = 0, 7 do
            for ccx = 0, 3 do
              local col = img:getPixel(cx * 4 + ccx, cy * 8 + ccy)
              if not setContains(cellCols, col) then
                addToSet(cellCols, col)
              end
            end
          end

          local cellCount = setCount(cellCols)
          if cellCount < 3 or (cellCount == 3 and not setContains(cellCols, dlgdata.bgCol.index)) then
            local markCol = 20
            if cellCount == 2 then
              markCol = 19
            end
            if cellCount == 3 then
              markCol = 18
            end
            for ccy = 0, 7 do
              for ccx = 0, 3 do
                oppimg:putPixel(cx * 4 + ccx, cy * 8 + ccy, markCol)
              end
            end
          end
        end
      end

      -- add opportunity map layer to the image
      opplayer = spr:newLayer()
      opplayer.name = "Oppmap"
      opplayer.opacity = 128
      spr:newCel(opplayer, app.activeFrame, oppimg)
      opplayer:cel(app.activeFrame).image = oppimg

      -- restore active layer to stored (adding the error layer selects that layer as active)
      if actLayer ~= nil then
        app.activeLayer = actLayer
      end

      app.refresh()
    end
  )
end



local function toggleLayer(app, dlgdata, layername)
  local elayer = findLayer(app, layername)
  if elayer ~= nil then
    elayer.isVisible = not elayer.isVisible
    app.refresh()
  end

end



--TODO:
-- find best bg color
-- find error cells
-- find the color with the fewest pixels in that cell
-- change it to...? the closest color from the other 3? What is the closest? In luma?
local function quickFix(app, dlgdata)
  if checkPrerequesities(app)~=true then
    return
  end

  app.transaction(
    function()
      local spr = app.activeSprite

      local img = Image(spr.spec)
      img:drawSprite(spr, app.activeFrame)

      local fixlayer = spr:newLayer()
      fixlayer.name = "Fixlayer"
      spr:newCel(fixlayer, app.activeFrame, img)
      fixlayer:cel(app.activeFrame).image = img
    end
  )
end



local function findBGColor(app, dlgdata)
  if checkPrerequesities(app)~=true then
    return
  end

  local spr = app.activeSprite

  local errlayer = findLayer(app, "Errormap")
  if errlayer ~= nil then
    spr:deleteLayer(errlayer)
  end
  local opplayer = findLayer(app, "Oppmap")
  if opplayer ~= nil then
    spr:deleteLayer(opplayer)
  end

  local minErrors = 40*25+1
  local minIdx = nil
  for i = 1,16 do
    local numErrors = mapErrors(app, dlgdata, i, false)
    if numErrors<minErrors then
      minErrors = numErrors
      minIdx = i
    end
  end

  -- show best error map
  mapErrors(app, dlgdata, minIdx, true)

  -- store the dialog position
  local prevBounds = Rectangle(d.bounds.x, d.bounds.y, d.bounds.width, d.bounds.height)
  d:close()
  bgColor = Color(minIdx)
  buildWindow(prevBounds)

end


----------------------------------------------------------------------
-- START
----------------------------------------------------------------------


buildWindow = function(bounds)
  d = Dialog("Mark bad cells (C64 multicolor)")
  d:button {id = "findbgcol", text = "&Find best BG color", onclick = function() findBGColor(app, d.data) end}
    :color {id = "bgCol", color = bgColor}
    :button {id = "check", text = "&Check", focus = true, onclick = function() mapErrors(app, d.data, d.data.bgCol.index, true) end}
    :button {id = "toggle", text = "Toggle Errormap", onclick = function() toggleLayer(app, d.data, "Errormap") end}
    :newrow()
    :button {id = "opp", text = "&OppCheck", onclick = function() mapOpportunities(app, d.data) end}
    :button {id = "opptoggle", text = "Toggle Oppmap", onclick = function() toggleLayer(app, d.data, "Oppmap") end}
    -- Not yet
    --:newrow()
    --:button {id = "fix", text = "Quick fix", onclick = function() quickFix(app, d.data) end}

    -- restore dialog position and size if we got data for it
    if bounds then
      -- Not really working... Aseprite bug?
      d.bounds = bounds
      -- If there is one more command here, the position will be restored, but width/height still resets
      d.bounds.x = d.bounds.x
    end
    d:show {wait = false}
end

buildWindow()
