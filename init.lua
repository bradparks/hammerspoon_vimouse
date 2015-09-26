local screen = require 'hs.screen'
local log = require'hs.logger'.new('vimouse')
local grids = {}
local phrase = ""
local CURSOR_HIGHLIGHT_RADIUS = 60

local vimouse = {}
local NUM_ROWS = 10
local NUM_COLS = 10
local BASE_COLOR = {["red"]=1,["blue"]=0,["green"]=0,["alpha"]=1}

local MOUSE_MOVE_BIG_DELTA = 50 
local MOUSE_MOVE_SMALL_DELTA = 10
local MOUSE_MOVE_MICRO_DELTA = 2
local VIM_SMALL_MODIFIER = {"ctrl"}
local VIM_BIG_MODIFIER = {"shift"}
local VIM_MICRO_MODIFIER = {"ctrl","shift"}

local CELL_FONT_SIZE = 30
local CELL_FONT_OFFSET = 25 

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

KEYS:bind({"ctrl"}, "return", function()
  local ptMouse = hs.mouse.getAbsolutePosition()
  hs.eventtap.rightClick(ptMouse)
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

-- Bind arrow keys
function bindGlobalRepeat(modifier, key, callback)
  hs.hotkey.bind(modifier, key, callback, nil, callback)
end

local pageUpDownModifier = {"alt","shift"}
bindGlobalRepeat(pageUpDownModifier, "J", function()
  hs.eventtap.keyStroke({}, "pagedown")
end)
bindGlobalRepeat(pageUpDownModifier, "K", function()
  hs.eventtap.keyStroke({}, "pageup")
end)

local arrowModifier = {"alt"}
bindGlobalRepeat(arrowModifier, "H", function()
  hs.eventtap.keyStroke({}, "left")
end)
bindGlobalRepeat(arrowModifier, "J", function()
  hs.eventtap.keyStroke({}, "down")
end)
bindGlobalRepeat(arrowModifier, "K", function()
  hs.eventtap.keyStroke({}, "up")
end)
bindGlobalRepeat(arrowModifier, "L", function()
  hs.eventtap.keyStroke({}, "right")
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

function vimouse.switchToMonitor(num)
  vimouse.switchToCenterOfMonitor(num)
end

function vimouse.getCenterOfScreen(s)
  if (s == nil) then
    s = hs.mouse.getCurrentScreen()
  end

  local f = s:fullFrame()
  local x = f.x + f.w/2
  local y = f.y + f.h/2
  local result = {x=x, y=y}
  assert(result, "Missing rect")

  return result
end

function vimouse.getCenterOfMonitor(num)
  num = tonumber(num)
  if (num == nil) then
    return nil
  end

  local screens=screen.allScreens()
  local s = screens[num]
  return vimouse.getCenterOfScreen(s)
end

function vimouse.switchToCenterOfMonitor(num)
  local pt = vimouse.getCenterOfMonitor(num)
  if (not (pt == nil)) then
    vimouse.moveMouse(pt.x, pt.y)
  end
end

function vimouse.processAction(data)
  vimouse.debug("JUMP " .. data) 
  local char1 = string.sub(data,1,1)
  local char2 = string.sub(data,2,2)
  local col = string.byte(char1) - 65
  local row = string.byte(char2) - 65
  if (char1 == "M") then
    vimouse.switchToMonitor(char2)
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
  vimouse.createGridForEachMonitor()

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

function vimouse.drawGridInFrame(id, cols,rows,f)
  local result = {}
  local width = vimouse.divide(f.w,rows)
  local height = vimouse.divide(f.h,cols)

  for i=1,rows do
    for j=1,cols do
      local x = f.x + (i-1) * width
      local y = f.y + (j-1) * height
      local items = vimouse.createCell(x,y,width,height,i,j,f)
      for _,item in ipairs(items) do
        table.insert(result, item)
      end
    end
  end

  local pt = vimouse.getCenterOfScreen()
  local size = 100
  local txtRect = hs.geometry.rect(pt.x-size,pt.y-size,size*2,size*2)
  local label = id
  local monitorLabel = vimouse.textInRect(txtRect, label)
  monitorLabel:setTextSize(200)
  table.insert(result, monitorLabel)

  return result
end

function vimouse.textInRect(r,text)
  assert(r, "Bad text in rect call")
  local result = hs.drawing.text(r, text)
  result:setTextColor(BASE_COLOR)
  result:setTextStyle({alignment="center"})

  return result
end

function vimouse.createGridForEachMonitor()
  vimouse.deleteGridForEachMonitor()
  grids = {}

  local screens=screen.allScreens()
  for index,s in ipairs(screens) do
    local f=s:fullFrame()
    local sid = index
    local grid = vimouse.drawGridInFrame(sid, NUM_COLS,NUM_ROWS,f)
    table.insert(grids, grid)
  end
end

function vimouse.deleteGridForEachMonitor()
  vimouse.deleteGrids(grids)
end

function vimouse.createCell(x,y,w,h,row,col,f)
  --return vimouse.createCellUsingRect(x,y,w,h,row,col,f)
  return vimouse.createCellUsingLines(x,y,w,h,row,col,f)
end

function vimouse.createCellUsingLines(x,y,w,h,row,col,f)
    local result = {}
    local ptTopLeft
    local ptBottomRight

    if (col == 1) then
      ptTopLeft = {x=x, y=y}
      ptBottomRight = {x=x, y=y+f.h}
    end
    if (row == 1) then
      ptTopLeft = {x=x, y=y}
      ptBottomRight = {x=x+f.w, y=y}
    end

    if (ptTopLeft ~= nil) then
      local line = hs.drawing.line(ptTopLeft, ptBottomRight)
      line:setStrokeColor(BASE_COLOR)
      line:setStrokeWidth(1)
      table.insert(result, line)
    end

    local txtRect = hs.geometry.rect(x,y+CELL_FONT_OFFSET,w,h)
    assert(txtRect)
    local label = string.char(65+row-1) .. string.char(65+col-1)
    local txt = vimouse.textInRect(txtRect, label)
    txt:setTextSize(CELL_FONT_SIZE)

    table.insert(result, txt)

    return result
end

function vimouse.createCellUsingRect(x,y,w,h,row,col)
    local r = hs.geometry.rect(x,y,w,h)
    local rect = hs.drawing.rectangle(r)
    rect:setStrokeColor({["red"]=1,["blue"]=0,["green"]=0,["alpha"]=1})
    rect:setFill(false)
    rect:setStrokeWidth(1)

    local txtRect = hs.geometry.rect(x,y+CELL_FONT_OFFSET,w,h)
    local label = string.char(65+row-1) .. string.char(65+col-1)
    local txt = vimouse.textInRect(txtRect, label)
    txt:setTextSize(CELL_FONT_SIZE)

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
    local pt = {x=ptMouse.x-CURSOR_HIGHLIGHT_RADIUS, y=ptMouse.y-CURSOR_HIGHLIGHT_RADIUS}
    if (not vimouse.mouseCircle) then
      vimouse.mouseCircle = hs.drawing.circle(hs.geometry.rect(pt.x, pt.y, CURSOR_HIGHLIGHT_RADIUS*2, CURSOR_HIGHLIGHT_RADIUS*2))
      vimouse.mouseCircle:setStrokeColor(BASE_COLOR)
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
  local screen = hs.mouse.getCurrentScreen()
  local r = screen:fullFrame()
  local path = "/tmp/grid1.pdf"
  local gridImage = hs.image.imageFromPath(path)
  local result = hs.drawing.image(r, gridImage)
  result:show()

  return result;
end

--vimouse.drawImageGrid()
vimouse.bindKeys()
startWatchingForMonitorChanges()
vimouse.createGridForEachMonitor()

return vimouse

