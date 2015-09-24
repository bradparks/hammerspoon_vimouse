local screen = require 'hs.screen'
local log = require'hs.logger'.new('vimouse')
local vimouse = {}
local NUM_ROWS = 10
local NUM_COLS = 10
local grids = {}
local phrase = ""
local vimModifier = {"ctrl"}
local radius = 60

function startWatchingForMonitorChanges()
  local screenWatcher = hs.screen.watcher.new(function()
    hs.alert.show('RESOLUTION changed') 
    vimouse.createGridForEachMonitor()
  end)
  screenWatcher:start()
end

-- Convert from table to CSV string
function toCSV (tt)
  return hs.inspect.inspect(tt)
  --[[
  local s = ""
  for _,p in ipairs(tt) do  
    s = s .. "," .. escapeCSV(p)
  end
  return string.sub(s, 2)      -- remove first comma
  --]]
end

KEYS = hs.hotkey.modal.new({"cmd","ctrl","alt"}, "b")
function KEYS:entered() 
  hs.alert.show('Entered mode') 
end
function KEYS:exited()  
  hs.alert.show('Exited mode')  
end
function vimouse.moveLeft() 
  vimouse.moveMouseDelta(-1,0)
end
function vimouse.moveDown() 
  vimouse.moveMouseDelta(0,1)
end
function vimouse.moveUp() 
  vimouse.moveMouseDelta(0,-1)
end
function vimouse.moveRight() 
  vimouse.moveMouseDelta(1,0)
end

function bindRepeat(key, callback, modifier)
  KEYS:bind(modifier, key, callback, callback, callback)
end
KEYS:bind({"return"}, "", function()
  hs.alert.show("RETURN")
end)

bindRepeat('H', vimouse.moveLeft, vimModifier)
bindRepeat('J', vimouse.moveDown, vimModifier)
bindRepeat('K', vimouse.moveUp, vimModifier)
bindRepeat('L', vimouse.moveRight, vimModifier)

function vimouse.processAction(data)
  -- local x = string.byte(key)
  --local x = string.byte(data)
  local char1 = string.sub(data,1,1)
  local char2 = string.sub(data,2,2)
  local col = string.byte(char1) - 65
  local row = string.byte(char2) - 65
  local delta = 100

  --local screen = hs.window.focusedWindow():screen():fullFrame()
  --local pt = {x=-1,y=0}
  local screen = hs.mouse.getCurrentScreen()
  local f = screen:fullFrame()
  local rectWidth = (f.w / NUM_COLS)
  local rectHeight = (f.h / NUM_ROWS)
  hs.alert.show("Pressed " .. data) 

  vimouse.moveMouse(f.x + col*rectWidth + rectWidth/2, f.y + row*rectHeight + rectHeight / 2)
  vimouse.refreshBigCursor()
end

function vimouse.processKey(key)
  phrase = phrase .. key
  hs.alert.show("Pressed " .. key) 

  hs.alert.show("Phrase " .. phrase) 
  if (string.len(phrase) == 2) then
    hs.alert.show("ACTION " .. phrase) 
    vimouse.processAction(phrase)
    phrase = ""
  else
    refreshClearPhrase()
  end
end

function vimouse.bindKey(key)
  KEYS:bind({}, key, function()
    vimouse.processKey(key)
  end)
end

function vimouse.bindKeys()
    local keys = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    for i = 1, string.len(keys) do  -- The range includes both ends.
      local key = string.sub(keys,i,i)
      vimouse.bindKey(key)
    end
end
vimouse.bindKeys()

vimouse.mouseCircle = nil
vimouse.mouseCircleTimer = nil
vimouse.clearPhraseTimer = nil
vimouse.gridVisible = true

function vimouse.toggle()
    if (vimouse.gridVisible) then
      hs.vimouse.show()
    else
      hs.vimouse.hide()
    end

    vimouse.gridVisible = not vimouse.gridVisible
end

function vimouse.hideBigCursor()
  -- Delete an existing highlight if it exists
  if vimouse.mouseCircle then
      vimouse.mouseCircle:hide()
      if vimouse.mouseCircleTimer then
          vimouse.mouseCircleTimer:stop()
      end
  end
end

function vimouse.doHide()
    --vimouse.deleteGridForEachMonitor()
    vimouse.toggleGridVisibility(grids, false)
    vimouse.hideBigCursor()
end

function vimouse.hide()
  KEYS:exit()
  vimouse.doHide()
end

function vimouse.deleteGrid(grid)
  for index, cell in ipairs(grid) do 
    cell:delete()
  end
end

function vimouse.deleteGrids(gridsToIterate)
  for index,grid in ipairs(gridsToIterate) do
  log.w('iterate grid:' .. index)
    vimouse.deleteGrid(grid)
  end
  for index,grid in ipairs(gridsToIterate) do
    grids[index] = nil
  end
end

function vimouse.toggleGridVisibility(gridsToIterate, shouldShow)
  for i,grid in ipairs(gridsToIterate) do
    for j,cell in ipairs(grid) do
      --log.w('VISIBLE.g', shouldShow, cell)
      if shouldShow then
        cell:show()
      else
        cell:hide()
      end
    end
  end
end

function vimouse.divide(a,b)
  local c = (a - a % b) / b
  return c
end

function vimouse.drawGridInFrame(cols,rows,f)
  log.w('Screen.f', cols,rows, f.w, f.h)
  local result = {}
  local width = vimouse.divide(f.w,rows)
  local height = vimouse.divide(f.h,cols)

  for i=1,rows do
    for j=1,cols do
      local x = f.x + (i-1) * width
      local y = f.y + (j-1) * height
      local items = vimouse.createCell(x,y,width,height,i,j)
      for _,item in ipairs(items) do
        table.insert(result, item)
      end
      --log.w('x,y,top,right', x,y,x+width,y+height)
    end
  end

  return result
end

function vimouse.textInRect(r,text)
  local width = vimouse.divide(r.w,NUM_ROWS)
  local height = vimouse.divide(r.h,NUM_COLS)
  local result = hs.drawing.text(r, text)

  return result
end

function vimouse.createGridForEachMonitor()
  vimouse.deleteGridForEachMonitor()
  grids = {}

  local screens=screen.allScreens()
  for _,s in ipairs(screens) do
    local f=s:fullFrame()
    local sid = s:id()
    local grid = vimouse.drawGridInFrame(NUM_COLS,NUM_ROWS,f)
    --local grid = vimouse.drawImageGrid(NUM_COLS,NUM_ROWS,f)
    table.insert(grids, grid)
  end
end

function vimouse.deleteGridForEachMonitor()
  vimouse.deleteGrids(grids)
end

function vimouse.createCell(x,y,w,h,row,col)
    local r = hs.geometry.rect(x,y,w,h)
    local rect = hs.drawing.rectangle(r)
    rect:setStrokeColor({["red"]=1,["blue"]=0,["green"]=0,["alpha"]=1})
    rect:setFill(false)
    rect:setStrokeWidth(1)

    local fontSize = 40
    local txtRect = hs.geometry.rect(x,y+fontSize/2,w,h)
    local label = string.char(65+row-1) .. string.char(65+col-1)
    local txt = vimouse.textInRect(txtRect, label)
    txt:setTextColor({["red"]=1,["blue"]=0,["green"]=0,["alpha"]=1})
    txt:setTextStyle({alignment="center"})
    txt:setTextSize(40)

    local result = {}
    table.insert(result, rect)
    table.insert(result, txt)

    return result
end

function vimouse.moveMouse(x,y)
    local ptMouse = {x=x, y=y}
    hs.mouse.setAbsolutePosition(ptMouse)
end

function vimouse.moveMouseDelta(deltaX,deltaY)
    -- local ptMouse = {x=910, y=259}
    local ptMouse = hs.mouse.getAbsolutePosition()
    ptMouse.x = ptMouse.x + deltaX * 40
    ptMouse.y = ptMouse.y + deltaY * 40
    --hs.alert.show("ENTERED MODE") 
  --hs.notify.new({title="Hammerspoon", alwaysPresent=true, autoWithdraw=true, informativeText="Hello World"}):send():release()
    hs.mouse.setAbsolutePosition(ptMouse)
    vimouse.refreshBigCursor()
    --hs.alert.show("mouse:" .. toCSV(ptMouse))
end

function vimouse.refreshBigCursor()
    vimouse.hideBigCursor()

    local ptMouse
    ptMouse = hs.mouse.getAbsolutePosition()

    --hs.alert.show("mouse:" .. toCSV(ptMouse))
    hs.alert.show("mouse:" .. ptMouse.x .. " " .. ptMouse.y)
    -- Prepare a big red circle around the mouse pointer
    local pt = {x=ptMouse.x-radius, y=ptMouse.y-radius}
    if (not vimouse.mouseCircle) then
      vimouse.mouseCircle = hs.drawing.circle(hs.geometry.rect(pt.x, pt.y, radius*2, radius*2))
      --vimouse.mouseCircle = hs.drawing.rectangle(hs.geometry.rect(ptMouse.x-40, ptMouse.y-40, 80, 80))
      vimouse.mouseCircle:setStrokeColor({["red"]=1,["blue"]=0,["green"]=0,["alpha"]=1})
      vimouse.mouseCircle:setFill(false)
      vimouse.mouseCircle:setStrokeWidth(7)
      vimouse.mouseCircle:show()
    else
      vimouse.mouseCircle:setTopLeft(pt)
      vimouse.mouseCircle:show()
    end

    vimouse.mouseCircleTimer = hs.timer.doAfter(1, function() 
      vimouse.hideBigCursor()
    end)
end


function refreshClearPhrase()
    if vimouse.clearPhraseTimer then
        vimouse.clearPhraseTimer:stop()
    end
    vimouse.clearPhraseTimer = hs.timer.doAfter(1, function() 
      phrase = ""
      hs.alert.show('Phrase cleared')
    end)
end

function vimouse.saveSettings()
  hs.settings.set("grix_x", x)
  hs.settings.set("grix_y", y)
  --hs.settings.get("grix_y")
end

function vimouse.show()
    KEYS:enter()
    vimouse.doHide()
    vimouse.toggleGridVisibility(grids, true)

    vimouse.refreshBigCursor()
end

function vimouse.drawImageGrid(cols,rows,r)
  local path = "/tmp/download.png"
  local gridImage = hs.image.imageFromPath(path)
  --local r = {x=10,y=10,w=500,h=500}
  local it = hs.drawing.image(r, gridImage)
  --it:show()
  return it;
end

--vimouse.drawImageGrid()
startWatchingForMonitorChanges()
vimouse.createGridForEachMonitor()

return vimouse

