--[[
-- save recent mouse move locations, display as circles, like heat map, colored for clicking with labels
-- allow history navigation of mouse positions 
    -- When switching monitors, move to the came cell as we were in (lastPhrase)
    -- Display monitor # in the top middle of screen for a sec?
    -- Switch monitor focus to main app in monitor
    -- Big Move moves in 1/3 of big grid size, so with 3 moves, you're always ending up on the center of a block.
    -- Swtich to monitor of the active window on show?
    -- Double tap enter dismisses grid
    -- Spacebar for scroll? and Shift_Spacebar for backscroll?
    -- change grid to ascii or just lines or maybe other image type?
    -- add right click
    --
    --
local fadeTween = tween.new(2, properties, {bgcolor = {0,0,0}, fgcolor={255,0,0}}, 'linear')
fadeTween:update(dt)
--]]


--require("luarocks.loader")
--local pkg = require("luasocket")

local tween = require 'vimouse/tween'


local screen = require 'hs.screen'
local log = require'hs.logger'.new('vimouse')
local grids = {}
local monitorCues = {}
local browsers = {}
local phrase = ""
local CURSOR_HIGHLIGHT_RADIUS = 60

local vimouse = {}
local NUM_ROWS = 10
local NUM_COLS = 10
local BASE_COLOR = {["red"]=1,["blue"]=0,["green"]=0,["alpha"]=1}
local CELL_FONT_SIZE = 25 
local CELL_FONT_OFFSET = 19 

local MONITOR_LABEL_FONT_SIZE = 200
local MONITOR_CUE_TIMER_INTERVAL_IN_SECONDS = 5
local MONITOR_LABEL_ALPHA = 0.5 

local MOUSE_MOVE_SMALL_DELTA = 10
local MOUSE_MOVE_MICRO_DELTA = 2
local VIM_BIG_MODIFIER = {"ctrl","shift"}
local VIM_SMALL_MODIFIER = {"ctrl"}
local VIM_MICRO_MODIFIER = {"shift"}

local VIM_BIG_MODIFER_DELTA = 1
local VIM_SMALL_MODIFER_DELTA = 8 
local VIM_MICRO_MODIFER_DELTA = 16

local SCROLL_DELTA = 50
local SCROLL_MODE = 'pixel'

local lastAction = ''
local lastPhrase = ''

function isMissing(v)
  return not isDefined(v)
end

function isDefined(v)
  if (v == nil) then 
    return false
  end
  local x = v .. ""

  if (string.len(x) > 0) then
    return false
  end

  return true
end

function vimouse.validPhrase(p)
  local v = p
  if (p == nil) then
    p = phrase
  end 
  local result = string.len(p) == 2
  return result
end

function track(action)
  lastAction = action
  log.w("action:", action)
end

function vimouse.debug(msg, more)
   log.w(msg)
   hs.alert.show(msg)
   if more ~= nil then
      hs.notify.new({title="VIMouse", informativeText=msg}):send()
   end
end

function vimouse.alert(msg, more)
    log.w(msg)
    hs.alert.show(msg)
    if more ~= nil then
      hs.notify.new({title="VIMouse", informativeText=msg}):send()
    end
end

function onKeyPress(modifiers,event,c,d,e,f,g)
  hs.eventtap.keyStroke(modifiers,event,c,d,e,f,g)
  track(event)
end

function startWatchingForMonitorChanges()
  local screenWatcher = hs.screen.watcher.new(function()
    vimouse.debug('RESOLUTION changed', true) 
    vimouse.recreateGridsForEachMonitor()
  end)
  screenWatcher:start()
end

function toCSV (tt)
  return hs.inspect.inspect(tt)
end

KEYS = hs.hotkey.modal.new()
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

-- bind return or enter key to click
KEYS:bind({""}, "return", function()
  local ptMouse = hs.mouse.getAbsolutePosition()
  if (lastAction == "leftclick") then
    vimouse.toggle()
    return
  end

  hs.eventtap.leftClick(ptMouse)

  vimouse.debug("RETURN")
  track("leftclick")

  if (vimouse.textFieldIsSelected()) then
    vimouse.toggle()
    return
  end
end)

-- bind return or enter key to right click
KEYS:bind({"shift"}, "return", function()
  track("rightclick")
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
  onKeyPress({}, "pagedown")
end)
bindGlobalRepeat(pageUpDownModifier, "K", function()
  onKeyPress({}, "pageup")
end)

local arrowModifier = {"alt"}
bindGlobalRepeat(arrowModifier, "H", function()
  onKeyPress({}, "left")
end)
bindGlobalRepeat(arrowModifier, "J", function()
  onKeyPress({}, "down")
end)
bindGlobalRepeat(arrowModifier, "K", function()
  onKeyPress({}, "up")
end)
bindGlobalRepeat(arrowModifier, "L", function()
  onKeyPress({}, "right")
end)

bindRepeat('H', VIM_MICRO_MODIFIER,  function()
  vimouse.moveLeft(vimouse.getCurrentScreenWidth() / VIM_MICRO_MODIFER_DELTA)
end)
bindRepeat('J', VIM_MICRO_MODIFIER,  function()
  vimouse.moveDown(vimouse.getCurrentScreenHeight() / VIM_MICRO_MODIFER_DELTA)
end)
bindRepeat('K', VIM_MICRO_MODIFIER,  function()
  vimouse.moveUp(vimouse.getCurrentScreenHeight() / VIM_MICRO_MODIFER_DELTA)
end)
bindRepeat('L', VIM_MICRO_MODIFIER,  function()
  vimouse.moveRight(vimouse.getCurrentScreenWidth() / VIM_MICRO_MODIFER_DELTA)
end)

bindRepeat('H', VIM_SMALL_MODIFIER,  function()
  vimouse.moveLeft(vimouse.getCurrentScreenWidth() / VIM_SMALL_MODIFER_DELTA)
end)
bindRepeat('J', VIM_SMALL_MODIFIER,  function()
  vimouse.moveDown(vimouse.getCurrentScreenHeight() / VIM_SMALL_MODIFER_DELTA)
end)
bindRepeat('K', VIM_SMALL_MODIFIER,  function()
  vimouse.moveUp(vimouse.getCurrentScreenHeight() / VIM_SMALL_MODIFER_DELTA)
end)
bindRepeat('L', VIM_SMALL_MODIFIER,  function()
  vimouse.moveRight(vimouse.getCurrentScreenWidth() / VIM_SMALL_MODIFER_DELTA)
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
bindRepeat('H', VIM_BIG_MODIFIER,  function()
  vimouse.moveLeft(vimouse.getCurrentScreenWidth() / VIM_BIG_MODIFER_DELTA)
end)
bindRepeat('J', VIM_BIG_MODIFIER,  function()
  vimouse.moveDown(vimouse.getCurrentScreenHeight() / VIM_BIG_MODIFER_DELTA)
end)
bindRepeat('K', VIM_BIG_MODIFIER,  function()
  vimouse.moveUp(vimouse.getCurrentScreenHeight() / VIM_BIG_MODIFER_DELTA)
end)
bindRepeat('L', VIM_BIG_MODIFIER,  function()
  vimouse.moveRight(vimouse.getCurrentScreenWidth() / VIM_BIG_MODIFER_DELTA)
end)

bindRepeat('R', VIM_BIG_MODIFIER,  function()
  vimouse.showBrowser()
end)
bindRepeat('T', VIM_BIG_MODIFIER,  function()
  vimouse.deleteBrowsers()
end)

function vimouse.deleteItems(items)
  for index,item in ipairs(items) do
    item:delete()
  end
end

function vimouse.deleteBrowsers()
  vimouse.deleteItems(browsers)
  browsers = {}
end

function vimouse.showBrowser()
  local rect = hs.geometry.rect(-500, -500, 500, 500)
  local wv = hs.webview.new(rect)
  local url = "http://www.hammerspoon.org/docs/hs.webview.html#new"
  url = "file:///Users/bparks/gitrepos/genie/demo/index.html"
  url = "file:///db/vimouse/test.html"
  url = "file:///Users/bparks/gitrepos/atom_examples/bap1/paper/grid.html"
  url = "http://www.hammerspoon.org/docs/hs.webview.html#new"

  wv:url(url)


  local mask = {borderless = true, utility = false, titled = true}
  mask.borderless = false
  mask.utility = false
  mask.titled = true
  wv:windowStyle(mask)

  wv:show()
  table.insert(browsers,wv)

  --wv:asHSDrawing():setFrame(hs.geometry.rect(-100, -100, 100, 200))
end

function vimouse.showBrowserCircle()
  local rect = hs.geometry.rect(-100, -100, 100, 200)
  local mouseCircle = hs.drawing.circle(rect)
  local BASE_COLOR = {["red"]=1,["blue"]=0,["green"]=0,["alpha"]=1}

  mouseCircle:setStrokeColor(BASE_COLOR)
  mouseCircle:setFill(false)
  mouseCircle:setStrokeWidth(7)
  mouseCircle:show()
end

function vimouse.showBrowserOldd()
  local width = 400
  local height = 200
  log.w("showbrowser")
  local s = vimouse.getCurrentScreen()
  log.w("showbrowser.1", s)

  --local rect = vimouse.getRectInCenterOfScreen(width,height,s)
  local rect = hs.geometry.rect(0, 0, 100, 200)
  log.w("showbrowser.2", rect)
  --log.w("RECT:", rect)
  local wv = hs.webview.new(rect)
  --log.w("wv:", wv)
  local url = "file:///db/vimouse/dialog.html"
  --log.w("pwd:", hs.fs.currentDir())
  wv:url(url)
  wv:show()
  table.insert(browsers,wv)

  return wv
end

function vimouse.executeLastPhrase()
  if (vimouse.validPhrase(lastPhrase)) then
    vimouse.processAction(lastPhrase)
    return true
  else
    vimouse.switchToCenterOfMonitor()
  end

  return false
end

function vimouse.switchToMonitor(num)
  vimouse.switchToCenterOfMonitor(num, false)
  if not vimouse.executeLastPhrase() then
      vimouse.refreshBigCursor()
  end
end

function vimouse.getRectInCenterOfScreen(width,height,s)
  local pt = vimouse.getCenterOfScreen(s)
  local result = hs.geometry.rect(pt.x - width/2,pt.y - height/2,width,height)

  return result
end

function vimouse.getCurrentScreen(s)
  if s ~= nil then
    return s
  end

  local result = hs.mouse.getCurrentScreen()
  if (result ~= nil) then
    return result
  end

  result = hs.screen.mainScreen()
  if (result ~= nil) then
    return result
  end

  result = hs.screen.primaryScreen()
  return result
end

function vimouse.getCenterOfScreen(s)
  s = vimouse.getCurrentScreen(s)

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

function vimouse.switchToCenterOfMonitor(num, hilightCursor)
  local pt = vimouse.getCenterOfMonitor(num)
  if (not (pt == nil)) then
    vimouse.moveMouse(pt.x, pt.y,hilightCursor)
  end
end

function vimouse.processAction(data)
  local char1 = string.sub(data,1,1)
  local char2 = string.sub(data,2,2)
  local col = string.byte(char1) - 65
  local row = string.byte(char2) - 65

  if (char1 == "M") then
    vimouse.switchToMonitor(char2)
    vimouse.setMonitorCueVisibility(false)
    return
  end

  vimouse.debug("JUMP " .. data) 

  local s = vimouse.getCurrentScreen()
  local f = s:fullFrame()
  local rectWidth = (f.w / NUM_COLS)
  local rectHeight = (f.h / NUM_ROWS)

  lastPhrase = data

  vimouse.moveMouse(f.x + col*rectWidth + rectWidth/2, f.y + row*rectHeight + rectHeight/2 - CELL_FONT_OFFSET)
end

function vimouse.getCurrentScreenHeight()
  local size = vimouse.getCurrentScreenSize()
  local result = size.h
  return result
end

function vimouse.getCurrentScreenWidth()
  local size = vimouse.getCurrentScreenSize()
  local result = size.w
  return result
end

function getCurrentScreenHeight()
end

function vimouse.getCurrentScreenSize()
  local result = {}

  local s = vimouse.getCurrentScreen()
  if (s == nil) then
    return
  end 

  local f = s:fullFrame()
  result.w = f.w / NUM_COLS
  result.h = f.h / NUM_ROWS

  return result
end

function vimouse.processKey(key)
  track(key)

  phrase = phrase .. key
  vimouse.alert("Pressed " .. key) 

  if vimouse.validPhrase(phrase) then
    vimouse.alert("ACTION " .. phrase) 
    vimouse.processAction(phrase)
    phrase = ""
  elseif string.len(phrase) == 1 and key == "M" then
    vimouse.setMonitorCueVisibility(true)
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
vimouse.monitorCueTimer = nil
vimouse.clearPhraseTimer = nil
vimouse.gridVisible = true

function vimouse.getScreenForMonitor(num)
    local screens=screen.allScreens()
    local s = screens[num]
    return s
end

function vimouse.getMonitorForWindow(win)
  local screens=screen.allScreens()
  for index,s in ipairs(screens) do
    if (s == win:screen()) then
      return index
    end
  end

  return nil
end

function vimouse.getFocusedMonitorNumber()
  local w = hs.window.frontmostWindow()
  if (w ~= nil) then
    local result = vimouse.getMonitorForWindow(w)
    return result
  end
  return nil
end

function vimouse.textFieldIsSelected()
    local e = hs.uielement.focusedElement()
    if (e == nil) then
      log.w("no ui element focused")
      return false
    end

    local role = e:role()
    log.w("ui element:" .. role)
    if (string.find(role, "TextField") ~= nil) then
      return true
    end
    if (string.find(role, "TextArea") ~= nil) then
      return true
    end

    return false
end

function vimouse.info()
  local w = hs.window.frontmostWindow()
  if (w ~= nil) then
    local monitorNumber = vimouse.getMonitorForWindow(w)
    --vimouse.alert(w:title() .. "." .. monitorNumber)
    local e = hs.uielement.focusedElement()
    if (e ~= nil) then
      log.w("focused element", e:role(), vimouse.textFieldIsSelected())
    end
  end
end

function vimouse.toggle()
  lastAction = ""

  if (vimouse.gridVisible) then
    hs.vimouse.show()
  else
    hs.vimouse.hide()
  end
  vimouse.info()

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

function vimouse.deleteMonitorCues()
  for index,cue in ipairs(monitorCues) do
    cue:delete()
  end
  monitorCues = {}
end

function vimouse.setMonitorCueVisibility(shouldShow)
  for index,cue in ipairs(monitorCues) do
    if (shouldShow) then
      cue:show()
    else
      cue:hide()
    end
  end
end

function vimouse.doHide()
    vimouse.toggleGridVisibility(grids, false)
    vimouse.hideBigCursor()
end

function vimouse.deleteGrid(grid)
  for index, cell in ipairs(grid) do 
    cell:delete()
  end
end

function vimouse.deleteGrids(gridsToIterate)
  for index,grid in ipairs(gridsToIterate) do
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

      local items = vimouse.createCell(id, x,y,width,height,i,j,f)
      for _,item in ipairs(items) do
        table.insert(result, item)
      end
    end
  end

  return result
end

function vimouse.createMonitorCue(s, index)
  local pt = vimouse.getCenterOfScreen(s)
  local size = 100
  local txtRect = hs.geometry.rect(pt.x-size,pt.y-size,size*2,size*2)
  --log.w("MONITOR CUE AT:", toCSV(txtRect))
  local label = index
  local monitorLabel = vimouse.textInRect(txtRect, label)
  monitorLabel:setTextSize(MONITOR_LABEL_FONT_SIZE)
  monitorLabel:setAlpha(MONITOR_LABEL_ALPHA)

  table.insert(monitorCues, monitorLabel)
end

function vimouse.textInRect(r,text)
  assert(r, "Bad text in rect call")
  local result = hs.drawing.text(r, '' .. text)
  result:setTextColor(BASE_COLOR)
  result:setTextStyle({alignment="center"})

  return result
end

function vimouse.recreateGridsForEachMonitor()
  vimouse.deleteGridForEachMonitor()
  vimouse:deleteMonitorCues()

  local screens=screen.allScreens()
  for index,s in ipairs(screens) do
    local f=s:fullFrame()
    local sid = index
    local grid = vimouse.drawGridInFrame(sid, NUM_COLS,NUM_ROWS,f)
    table.insert(grids, grid)

    vimouse.createMonitorCue(s, index)
  end
end

function vimouse.deleteGridForEachMonitor()
  vimouse.deleteGrids(grids)
  grids = {}
end

function vimouse.createCell(id, x,y,w,h,row,col,f)
  --return vimouse.createCellUsingRect(id, x,y,w,h,row,col,f)
  return vimouse.createCellUsingLines(id, x,y,w,h,row,col,f)
end

function vimouse.createCellUsingLines(id,x,y,w,h,row,col,f)
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

    local txtRect = hs.geometry.rect(x,y+CELL_FONT_OFFSET,w,h)
    assert(txtRect)
    local label = string.char(65+row-1) .. string.char(65+col-1)
    local txt = vimouse.textInRect(txtRect, label)
    txt:setTextSize(CELL_FONT_SIZE)

    table.insert(result, txt)

    return result
end

function vimouse.createCellUsingRect(id,x,y,w,h,row,col)
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

function vimouse.moveMouse(x,y,hilightCursor)
    local ptMouse = {x=x, y=y}
    hs.mouse.setAbsolutePosition(ptMouse)
    log.w("mouse pos:", toCSV(ptMouse))
    if (hilightCursor == nil) or (hilightCursor) then
      vimouse.refreshBigCursor()
    end
end

function vimouse.moveMouseDelta(deltaX,deltaY,multiplier)
    track('key')

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

function vimouse.showBigCursor()
    local ptMouse
    ptMouse = hs.mouse.getAbsolutePosition()
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
end

function vimouse.refreshBigCursor()
    vimouse.hideBigCursor()

    vimouse.showBigCursor()

    vimouse.mouseCircleTimer = hs.timer.doAfter(1, function() 
      vimouse.hideBigCursor()
    end)
end

function vimouse.clearMonitorCueTimer()
  if vimouse.monitorCueTimer then
      vimouse.monitorCueTimer:stop()
  end
end

function vimouse.initMonitorCueTimer()
  vimouse:clearMonitorCueTimer()
  vimouse.monitorCueTimer  = hs.timer.doAfter(MONITOR_CUE_TIMER_INTERVAL_IN_SECONDS, function() 
    vimouse.setMonitorCueVisibility(false)
    vimouse.monitorCueTimer = nil
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

function vimouse.switchToActiveMonitor()
  local num = vimouse.getFocusedMonitorNumber()
  if (num ~= nil) then
    vimouse.switchToMonitor(num)
    return true
  end
  return false
end

function vimouse.show()
    KEYS:enter()
    vimouse.doHide()
    vimouse.toggleGridVisibility(grids, true)

    vimouse.switchToActiveMonitor()
    vimouse.setMonitorCueVisibility(true)
    vimouse.refreshBigCursor()
    vimouse.initMonitorCueTimer()
end

function vimouse.hide()
  KEYS:exit()
  vimouse.doHide()
  vimouse.setMonitorCueVisibility(false)
end


function vimouse.drawImageGrid(cols,rows,r)
  local screen = vimouse.getCurrentScreen()
  local r = screen:fullFrame()
  local path = "/tmp/grid1.pdf"
  local gridImage = hs.image.imageFromPath(path)
  local result = hs.drawing.image(r, gridImage)
  result:show()

  return result;
end

--[[
function vimouse.testTween()
local properties = {}
local fadeTween = tween.new(2, properties, {bgcolor = {0,0,0}, fgcolor={255,0,0}}, 'linear')
fadeTween:update(dt)
    vimouse.mouseCircleTimer = hs.timer.doAfter(1, function() 
      vimouse.hideBigCursor()
    end)
end
]]--

--vimouse.drawImageGrid()
vimouse.bindKeys()
startWatchingForMonitorChanges()
vimouse.recreateGridsForEachMonitor()
--vimouse.showBrowser()
--vimouse.showBrowserCircle()

return vimouse
