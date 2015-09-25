local screen = require 'hs.screen'
local log = require'hs.logger'.new('vimouse')
local vimouse = {}
local NUM_ROWS = 10
local NUM_COLS = 10
local grids = {}
local phrase = ""
local VIM_BIG_MODIFIER = {"ctrl"}
local VIM_SMALL_MODIFIER = {"shift"}
local VIM_MICRO_MODIFIER = {"ctrl","shift"}
local radius = 60
local MOUSE_MOVE_BIG_DELTA = 50 
local MOUSE_MOVE_SMALL_DELTA = 10
local MOUSE_MOVE_MICRO_DELTA = 2
local SCROLL_DELTA = 50
local SCROLL_MODE = 'pixel'

function vimouse.debug(msg)
   --hs.alert.show(msg)
end
function vimouse.alert(msg)
    hs.alert.show(msg)
end

function startWatchingForMonitorChanges()
  local screenWatcher = hs.screen.watcher.new(function()
    vimouse.debug('RESOLUTION changed') 
    vimouse.createGridForEachMonitor()
  end)
  screenWatcher:start()
end

function toCSV (tt)
  return hs.inspect.inspect(tt)
end

KEYS = hs.hotkey.modal.new({"cmd","ctrl","alt"}, "b")
function KEYS:entered() 
  vimouse.debug('Entered mode') 
end
function KEYS:exited()  
  vimouse.debug('Exited mode')  
end
function vimouse.moveLeft(delta) 
  vimouse.moveMouseDelta(-1,0,delta)
end
function vimouse.moveDown(delta) 
  vimouse.moveMouseDelta(0,1,delta)
end
function vimouse.moveUp(delta) 
  vimouse.moveMouseDelta(0,-1,delta)
end
function vimouse.moveRight(delta) 
  vimouse.moveMouseDelta(1,0,delta)
end

function bindRepeat(key, modifier, callback)
  KEYS:bind(modifier, key, callback, nil, callback)
end

-- return or enter key
KEYS:bind({""}, "return", function()
  local ptMouse = hs.mouse.getAbsolutePosition()
  hs.eventtap.leftClick(ptMouse)
  vimouse.debug("RETURN")
end)

function scrollDown()
  vimouse.debug("scroll down")
  local offsets = {horizontal=0, vertical=SCROLL_DELTA} 
  hs.eventtap.scrollWheel(offsets, {}, unit, SCROLL_MODE) 
end

function scrollUp()
  vimouse.debug("scroll up")
  local offsets = {horizontal=0, vertical=SCROLL_DELTA} 
  hs.eventtap.scrollWheel(offsets, {}, unit, SCROLL_MODE) 
end

KEYS:bind({"ctrl"}, "return", function()
  scrollDown()
end)
KEYS:bind({"ctrl","shift"}, "return", function()
  scrollUp()
end)
bindRepeat('H', VIM_MICRO_MODIFIER,  function()
  vimouse.moveLeft(MOUSE_MOVE_MICRO_DELTA)
end)
bindRepeat('J', VIM_MICRO_MODIFIER,  function()
  vimouse.moveDown(MOUSE_MOVE_MICRO_DELTA)
end)
bindRepeat('K', VIM_MICRO_MODIFIER,  function()
  vimouse.moveUp(MOUSE_MOVE_MICRO_DELTA)
end)
bindRepeat('L', VIM_MICRO_MODIFIER,  function()
  vimouse.moveRight(MOUSE_MOVE_MICRO_DELTA)
end)
bindRepeat('H', VIM_SMALL_MODIFIER,  function()
  vimouse.moveLeft(MOUSE_MOVE_SMALL_DELTA)
end)
bindRepeat('J', VIM_SMALL_MODIFIER,  function()
  vimouse.moveDown(MOUSE_MOVE_SMALL_DELTA)
end)
bindRepeat('K', VIM_SMALL_MODIFIER,  function()
  vimouse.moveUp(MOUSE_MOVE_SMALL_DELTA)
end)
bindRepeat('L', VIM_SMALL_MODIFIER,  function()
  vimouse.moveRight(MOUSE_MOVE_SMALL_DELTA)
end)
bindRepeat('H', VIM_BIG_MODIFIER,  function()
  vimouse.moveLeft(MOUSE_MOVE_BIG_DELTA)
end)
bindRepeat('J', VIM_BIG_MODIFIER,  function()
  vimouse.moveDown(MOUSE_MOVE_BIG_DELTA)
end)
bindRepeat('K', VIM_BIG_MODIFIER,  function()
  vimouse.moveUp(MOUSE_MOVE_BIG_DELTA)
end)
bindRepeat('L', VIM_BIG_MODIFIER,  function()
  vimouse.moveRight(MOUSE_MOVE_BIG_DELTA)
end)

function vimouse.switchMonitor(num)
  num = tonumber(num)
  if (num == nil) then
    return
  end

  local screens=screen.allScreens()

  local s =screens[num]
  if (s == nil) then
    return
  end

  vimouse.debug("SWITCHED TO MONITOR:" .. num)
  local f = s:fullFrame()
  local x = f.x + f.w/2
  local y = f.y + f.h/2
  vimouse.moveMouse(x,y)
end

function vimouse.processAction(data)
  vimouse.debug("JUMP " .. data) 
  local char1 = string.sub(data,1,1)
  local char2 = string.sub(data,2,2)
  local col = string.byte(char1) - 65
  local row = string.byte(char2) - 65
  if (char1 == "M") then
    vimouse.switchMonitor(char2)
    return
  end
  local delta = 100

  local screen = hs.mouse.getCurrentScreen()
  local f = screen:fullFrame()
  local rectWidth = (f.w / NUM_COLS)
  local rectHeight = (f.h / NUM_ROWS)

  vimouse.moveMouse(f.x + col*rectWidth + rectWidth/2, f.y + row*rectHeight + rectHeight / 2)
end

function vimouse.getCurrentScreenSize()
  local result = {}

  local s = hs.mouse.getCurrentScreen()
  if (s == nil) then
    return
  end 

  local f = s:fullFrame()
  result.x = f.w / NUM_COLS
  result.y = f.h / NUM_ROWS

  return result
end


function vimouse.processKey(key)
  phrase = phrase .. key
  vimouse.alert("Pressed " .. key) 

  if (string.len(phrase) == 2) then
    vimouse.alert("ACTION " .. phrase) 
    vimouse.processAction(phrase)
    phrase = ""
  else
    refreshClearPhrase()
  end
end

function vimouse.bindKeys()
    local keys = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    for i = 1, string.len(keys) do  -- The range includes both ends.
      local key = string.sub(keys,i,i)
      vimouse.bindKey(key)
    end
end

function vimouse.bindKey(key)
  KEYS:bind({}, key, function()
    vimouse.processKey(key)
  end)
end

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
  if vimouse.mouseCircle then
      vimouse.mouseCircle:hide()
      if vimouse.mouseCircleTimer then
          vimouse.mouseCircleTimer:stop()
      end
  end
end

function vimouse.doHide()
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

    local fontSize = 30
    local verticalOffset = 25 
    local txtRect = hs.geometry.rect(x,y+verticalOffset,w,h)
    local label = string.char(65+row-1) .. string.char(65+col-1)
    local txt = vimouse.textInRect(txtRect, label)
    txt:setTextColor({["red"]=1,["blue"]=0,["green"]=0,["alpha"]=1})
    txt:setTextStyle({alignment="center"})
    txt:setTextSize(fontSize)
    txt:setAlpha(0.90)

    local result = {}
    table.insert(result, rect)
    table.insert(result, txt)

    return result
end

function vimouse.moveMouse(x,y)
    local ptMouse = {x=x, y=y}
    hs.mouse.setAbsolutePosition(ptMouse)
    vimouse.refreshBigCursor()
end

function vimouse.moveMouseDelta(deltaX,deltaY,multiplier)
    local ptMouse = hs.mouse.getAbsolutePosition()

    local size = {}
    if (multiplier == nil) then
      size = {x=20, y=20}
    else
      size = {x=multiplier, y=multiplier}
    end

    ptMouse.x = ptMouse.x + deltaX * size.x
    ptMouse.y = ptMouse.y + deltaY * size.y
    hs.mouse.setAbsolutePosition(ptMouse)
    vimouse.refreshBigCursor()
end

function vimouse.refreshBigCursor()
    vimouse.hideBigCursor()

    local ptMouse
    ptMouse = hs.mouse.getAbsolutePosition()

    -- Prepare a big red circle around the mouse pointer
    local pt = {x=ptMouse.x-radius, y=ptMouse.y-radius}
    if (not vimouse.mouseCircle) then
      vimouse.mouseCircle = hs.drawing.circle(hs.geometry.rect(pt.x, pt.y, radius*2, radius*2))
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
      vimouse.alert('Phrase cleared')
    end)
end

function vimouse.saveSettings()
  hs.settings.set("grix_x", x)
  hs.settings.set("grix_y", y)
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
  local result = hs.drawing.image(r, gridImage)

  return result;
end

--vimouse.drawImageGrid()
vimouse.bindKeys()
startWatchingForMonitorChanges()
vimouse.createGridForEachMonitor()

return vimouse

