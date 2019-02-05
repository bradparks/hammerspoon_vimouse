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

--local tween = require 'vimouse/tween'
--local graph = require("graphpaper")

local NUM_ROWS = 10 
local NUM_COLS = 10 

local screen = require 'hs.screen'
local log = require'hs.logger'.new('vimouse')
--local console = require("hs._asm.console")
local grids = {}
local mouseCues = {}
local monitorCues = {}
local browsers = {}
local phrase = ""
local CURSOR_HIGHLIGHT_RADIUS = 60

local vimouse = {}
local BASE_COLOR = {["red"]=1,["blue"]=0,["green"]=0,["alpha"]=1}
local CELL_FONT_SIZE = 25 
local CELL_FONT_OFFSET = 0 

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
local wantsDismissOnDoubleEnter = false

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

function vimouse.w(msg,a,b,c,d,e)
  if (e ~= nil) then
    log.w(msg,a,b,c,d,e)
  elseif (d ~= nil) then
    log.w(msg,a,b,c,d)
  elseif (c ~= nil) then
    log.w(msg,a,b,c)
  elseif (b ~= nil) then
    log.w(msg,a,b)
  elseif (a ~= nil) then
    log.w(msg,a)
  else 
    log.w(msg)
  end
end

function vimouse.validPhrase(p)
  if (p == nil) then
    return false
  end
  local result = string.len(p) >= 1
  return result
  --[[
  local v = p
  if (p == nil) then
    p = phrase
  end 
  local result = string.len(p) == 2
  return result
  --]]
end

function track(action)
  lastAction = action
  if (action == "leftclick" or action == "rightclick") then
    -- vimouse.debug("action:" .. action)
  end
end

function vimouse.debug(msg, more)
   vimouse.w(msg)
   hs.alert.show(msg)
   if more ~= nil then
      hs.notify.new({title="VIMouse", informativeText=msg}):send()
   end
end

function vimouse.alert(msg, more)
    vimouse.w(msg)
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
    vimouse.recreateGridsForEachMonitor()
  end)
  screenWatcher:start()
end

function toCSV (tt)
  return hs.inspect.inspect(tt)
end

KEYS = hs.hotkey.modal.new()
function vimouse.moveNE(delta) 
  vimouse.moveMouseDelta(1,-1,delta)
end
function vimouse.moveSE(delta) 
  vimouse.moveMouseDelta(1,1,delta)
end
function vimouse.moveSW(delta) 
  vimouse.moveMouseDelta(-1,1,delta)
end
function vimouse.moveNW(delta) 
  vimouse.moveMouseDelta(-1,-1,delta)
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

function vimouse.dismissIfDoubleEnter()
  if (not wantsDismissOnDoubleEnter) then
    return false
  end

  if (lastAction == "leftclick") then
    vimouse.toggle()
    return true
  end

  return false
end

function bindRepeat(key, modifier, callback)
  KEYS:bind(modifier, key, callback, nil, callback)
end

function vimouse.click()
  track("leftclick")
  local ptMouse = hs.mouse.getAbsolutePosition()
  hs.eventtap.leftClick(ptMouse)
  if (vimouse.textFieldIsSelected()) then
    vimouse.toggle()
    return true
  end
  return false
end

function vimouse.rightClick()
  track("rightclick")
  local ptMouse = hs.mouse.getAbsolutePosition()
  hs.eventtap.rightClick(ptMouse)
end

-- click bind return or enter key to click
KEYS:bind({"ctrl"}, "return", function()
  if (vimouse.dismissIfDoubleEnter()) then
    return
  end

  vimouse.click()
end)

KEYS:bind({"shift"}, "return", function()
  local keys = {cmd=true}
  vimouse.leftClickWithModifiers(keys)
end)

hs.hotkey.bind({"alt"}, "return", function()
  vimouse.rightClick();
end)

-- bind return or enter key to right click
function vimouse.leftClickWithModifiers(keys)
  local ptMouse = hs.mouse.getAbsolutePosition()
  local types = hs.eventtap.event.types
  hs.eventtap.event.newMouseEvent(types.leftMouseDown, ptMouse, keys):post()
  hs.eventtap.event.newMouseEvent(types.leftMouseUp, ptMouse, keys):post()
end

--[[
KEYS:bind({"cmd"}, "return", function()
  vimouse.rightClick()
end)
--]]

-- Bind arrow keys
function bindGlobalRepeat(modifier, key, callback)
  hs.hotkey.bind(modifier, key, callback, nil, callback)
end

local pageUpDownModifier1  = {"ctrl"}
bindGlobalRepeat(pageUpDownModifier1, "F", function()
  onKeyPress({}, "pagedown")
end)
bindGlobalRepeat(pageUpDownModifier1, "B", function()
  onKeyPress({}, "pageup")
end)

local pageUpDownModifier = {"alt","shift"}
bindGlobalRepeat(pageUpDownModifier, "J", function()
  onKeyPress({}, "pagedown")
end)
bindGlobalRepeat(pageUpDownModifier, "K", function()
  onKeyPress({}, "pageup")
end)

local arrowModifier = {"ctrl"}
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

function vimouse.showBrowserOldd()
  local width = 400
  local height = 200
  vimouse.w("showbrowser")
  local s = vimouse.getCurrentScreen()
  vimouse.w("showbrowser.1", s)

  --local rect = vimouse.getRectInCenterOfScreen(width,height,s)
  local rect = hs.geometry.rect(0, 0, 100, 200)
  vimouse.w("showbrowser.2", rect)
  --vimouse.w("RECT:", rect)
  local wv = hs.webview.new(rect)
  --vimouse.w("wv:", wv)
  local url = "file:///db/vimouse/dialog.html"
  --vimouse.w("pwd:", hs.fs.currentDir())
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
  vimouse.setMouseCueVisibility(false)
  vimouse.switchToCenterOfMonitor(num, false)
  vimouse.refreshMouseCueSizes()

  if not vimouse.executeLastPhrase() then
      vimouse.refreshBigCursor()
  end
  vimouse.setMouseCueVisibility(true)
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
  local has2chars = string.len(data) == 2
  local char1 = string.sub(data,1,1)

  if (has2chars) then
    log.w('has 2 chars')
    local char2 = string.sub(data,2,2)
    if (char1 == "M") then
      vimouse.switchToMonitor(char2)
      vimouse.setMonitorCueVisibility(false)
      return true
    end

    local jumpTo = vimouse.getJumpTo(data, char1, char2)
    if (jumpTo.success) then
      lastPhrase = data
      vimouse.jumpTo(jumpTo)
      return true
    end

    return false
  end

  local jumpToChild = vimouse.getJumpToChild(data, char1)
  if (jumpToChild.success) then
    vimouse.jumpToChild(jumpToChild)
    return true
  end

  return false
end

function tern( cond , T , F )
      if cond then return T else return F end
end

function vimouse.getDeltaFromIndex(index)
  if (index == 0) then
    return -1
  end
  if (index == 1) then
    return 0 
  end
  return 1
end

function vimouse.jumpToChildMoveInDirection(jumpTo)
  local r = vimouse.getMouseRect()
  local cellWidth = r.w / 3 / 8
  local cellHeight = r.h / 3 / 8

  local pt = hs.mouse.getAbsolutePosition()
  local deltaY = vimouse.getDeltaFromIndex(jumpTo.row)
  local deltaX = vimouse.getDeltaFromIndex(jumpTo.col)

  pt.x = pt.x + (cellWidth * deltaX)
  pt.y = pt.y + (cellHeight * deltaY)

  hs.mouse.setAbsolutePosition(pt)
  vimouse.refreshBigCursor()

  log.w("jumpToChild:",toCSV(jumpTo), deltaX, deltaY, toCSV(pt))
end

function vimouse.jumpToChild(jumpTo)
  vimouse.jumpToChildAbsolutePosition(jumpTo)
end

function vimouse.jumpToChildAbsolutePosition(jumpTo)
  local r = vimouse.getMouseRect()
  local cellWidth = r.w / 3 
  local cellHeight = r.h / 3

  local pt = hs.mouse.getAbsolutePosition()
  local deltaY = vimouse.getDeltaFromIndex(jumpTo.row)
  local deltaX = vimouse.getDeltaFromIndex(jumpTo.col)

  pt.x = pt.x + (cellWidth * deltaX)
  pt.y = pt.y + (cellHeight * deltaY)

  hs.mouse.setAbsolutePosition(pt)
  vimouse.refreshBigCursor()

  log.w("jumpToChild:",toCSV(jumpTo), deltaX, deltaY, toCSV(pt))
end

function vimouse.getJumpToChild(data, char1, char2)
  local result = {}
  local chars = "QWEASDZXC"
  local index = string.find(chars, char1)
  result.success = (index ~= nil)
  if (result.success) then
    index = index - 1
    result.col = index % 3
    result.row = math.floor(index / 3)
  end
  return result
end

function vimouse.getJumpTo(data, char1, char2)
  local result = {}
  local chars 

  --[[
  char = 'bceghijklnopqrtuvwxyz'
  char = 'abcdefghijklmnopqrstuvwxyz'
  char = string.sub('bfghijklnoprtuvy', x, x+1);
  ]]--

  chars = "BFGHIJKLNOPRTUVY"
  chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  chars = "BFGHIJKLNOPRTUVY"
  result.col = string.find(chars, char1);
  result.row = string.find(chars, char2);
  result.success = (result.col ~= nil) and (result.row ~= nil)
  if (result.success) then
    result.row = result.row - 1
    result.col = result.col - 1
  end
  log.w("jumpto", result.success, result.row, result.col, char1, char2)

  return result
end

function vimouse.jumpTo(jumpTo)
  local col = jumpTo.col
  local row = jumpTo.row

  local s = vimouse.getCurrentScreen()
  local f = s:fullFrame()
  local rectWidth = (f.w / NUM_COLS)
  local rectHeight = (f.h / NUM_ROWS)

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

  local phraseLength = string.len(phrase) 
  if (vimouse.processAction(phrase)) then
    vimouse.clearPhrase()
  elseif phraseLength >= 3 then
    vimouse.clearPhrase()
  elseif phraseLength == 1 and key == "M" then
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

function vimouse.getMonitorForScreen(targetScreen)
  local screens=screen.allScreens()
  for index,s in ipairs(screens) do
    if (s == targetScreen) then
      return index
    end
  end

  return nil
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

function vimouse.getMouseMonitorNumber()
  local s = hs.mouse.getCurrentScreen()
  local result = vimouse.getMonitorForScreen(s)
  return result
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
      vimouse.w("no ui element focused")
      return false
    end

    local role = e:role()
    vimouse.w("ui element:" .. role)
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
      --vimouse.w("focused element", e:role(), vimouse.textFieldIsSelected())
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

function vimouse.startDoubleClickTimer()
  if vimouse.dblClickTimer then
      vimouse.dblClickTimer:stop()
  end
  vimouse.dblClickTimer = hs.timer.doAfter(hs.eventtap.doubleClickInterval(), function() 
    vimouse.clickCount = vimouse.clickCount + 1;
  end)
end

function vimouse.hideBigCursor()
  vimouse.setMouseCueVisibility(false)
  if vimouse.mouseCircleTimer then
      vimouse.mouseCircleTimer:stop()
  end
end

function vimouse.deleteMonitorCues()
  for index,cue in ipairs(monitorCues) do
    cue:delete()
  end
  monitorCues = {}
end

function vimouse.setVisibility(items, shouldShow)
  for index,item in ipairs(items) do
    if (shouldShow) then
      item:show()
    else
      item:hide()
    end
  end
end

function vimouse.setMonitorCueVisibility(shouldShow)
  vimouse.setVisibility(monitorCues, shouldShow)
end

function vimouse.setMouseCueVisibility(shouldShow)
  vimouse.setVisibility(mouseCues, shouldShow)
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
      --vimouse.w('VISIBLE.g', shouldShow, cell)
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
  --vimouse.w("MONITOR CUE AT:", toCSV(txtRect))
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

    --local grid = vimouse.drawGridInFrame(sid, NUM_COLS,NUM_ROWS,f)
    local grid = vimouse.createGridForScreen(s)
    vimouse.addToGrids(grid)

    vimouse.createMonitorCue(s, index)
  end
end

function vimouse.addToGrids(item)
    local grid = {}
    table.insert(grid, item)
    table.insert(grids, grid)
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
    --vimouse.w("mouse pos:", toCSV(ptMouse))
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

function vimouse.getMouseRect(cellSize)
    cellSize = cellSize or vimouse.getCellSize()
    local delta = 1
    cellSize.w = delta * cellSize.w
    cellSize.h = delta * cellSize.h
    local ptMouse = hs.mouse.getAbsolutePosition()
    local x = ptMouse.x - 1 * cellSize.w;
    local y = ptMouse.y - 1 * cellSize.h;
    local w = 2 * cellSize.w;
    local h = 2 * cellSize.h;
    local result = hs.geometry.rect(x,y,w,h)
    return result
end

function vimouse.getMouseRect(cellSize)
    local pt = hs.mouse.getAbsolutePosition()
    local length = 100
    local w = length
    local h = length
    local half = length / 2
    local result = hs.geometry.rect(pt.x-half, pt.y-half,w,h)
    return result
end

function vimouse.createMouseCursorGrid()
    local r = vimouse.getMouseRect(cellSize)
    local grid;
    --grid = vimouse.createGridForRect(r, "chars_grid.png")
    --grid = vimouse.createGridForRect(r, "chars_grid2.png")
    --grid = vimouse.createGridForRect(r, "5x5.png")
    --grid = vimouse.createGridForRect(r, "3x3_square.png")

    --grid = vimouse.createGridForRect(r, "3x3_square_small.png")
    grid = vimouse.createGridForRect(r, "3x3_75.png")

    table.insert(mouseCues, grid)

    return grid
end

function vimouse.getMousePt()
    local ptMouse
    ptMouse = hs.mouse.getAbsolutePosition()
    local pt = {x=ptMouse.x-CURSOR_HIGHLIGHT_RADIUS, y=ptMouse.y-CURSOR_HIGHLIGHT_RADIUS}
    return pt
end

function vimouse.createMouseCursor()
    local r = vimouse.getMouseRect()

    --vimouse.mouseCircle = hs.drawing.circle(hs.geometry.rect(pt.x, pt.y, CURSOR_HIGHLIGHT_RADIUS*2, CURSOR_HIGHLIGHT_RADIUS*2))
    --bapbap
    vimouse.mouseCircle = hs.drawing.rectangle(r)
    vimouse.mouseCircle:setStrokeColor(BASE_COLOR)
    vimouse.mouseCircle:setFill(false)
    vimouse.mouseCircle:setStrokeWidth(7)

    table.insert(mouseCues, vimouse.mouseCircle)
end

function vimouse.refreshMouseCueSizes()
  local r = vimouse.getMouseRect()
  for index,item in ipairs(mouseCues) do
     item:setTopLeft(r)
     item:setSize(r)
  end
end

function vimouse.showBigCursor()
  --local pt = vimouse.getMousePt()
  local r = vimouse.getMouseRect()
  for index,item in ipairs(mouseCues) do
     item:setTopLeft(r)
  end
  vimouse.setMouseCueVisibility(true)
end

function vimouse.refreshBigCursor()
    vimouse.hideBigCursor()

    vimouse.showBigCursor()
    vimouse.mouseCircleTimer = hs.timer.doAfter(25, function() 
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
      vimouse.clearPhrase()
    end)
end

function vimouse.clearPhrase()
  phrase = ""
  --vimouse.alert('Phrase cleared')
end

function vimouse.saveSettings()
  hs.settings.set("grix_x", x)
  hs.settings.set("grix_y", y)
end

function vimouse.switchToActiveMonitor()
  local numActive = vimouse.getFocusedMonitorNumber()
  local numMouse = vimouse.getMouseMonitorNumber()
  if (numMouse == numActive) then
    return true
  end

  if (numActive ~= nil) then
    vimouse.switchToMonitor(numActive)
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
    vimouse.showBigCursor()
    vimouse.initMonitorCueTimer()
    vimouse.flashObject(vimouse.mouseCircle, false)
end

function vimouse.hide()
  KEYS:exit()
  vimouse.doHide()
  vimouse.setMonitorCueVisibility(false)
end

function vimouse.createGridForScreen(s)
  local r = s:fullFrame()
  local result = vimouse.createGridForRect(r)
  return result
end

function vimouse.createGridForRect(r, filePath)
  local default = "20x20.png"
  local default = "10x10.png"
  local default = "12x12.png"
  local default = "10x10_BFGH.png"
  local default = "10x10.png"

  local path = filePath or default

  path = vimouse.appFile(path);

  local gridImage = hs.image.imageFromPath(path)
  local result = hs.drawing.image(r, gridImage)
  result:imageScaling('scaleToFit');

  return result
end

function vimouse.scriptPath()
  local path = package.searchpath("vimouse",package.path)
  local result = string.sub(path,1,-9)
  return result
end

function vimouse.appFile(path)
  local result = vimouse.scriptPath() .. "/" .. path
  return result
end

function vimouse.test()
  vimouse.testTween()
end

function vimouse.repeatCallback(times, interval, callback)
  local config = {}
  config.j = 0
  config.max = times
  config.even = true

  local p = function ()
    if (config.j == config.max) then
      return false
    end
    config.j = config.j + 1
    return true
  end

  local a = function (t)
    local percent = config.j / config.max
    callback(percent, config)
    config.even = not config.even
  end

  local t = hs.timer.doWhile(p, a, interval) 
  a(t)
end

function vimouse.flashObject(obj, showWhenDone)
  local callback = function (percent, config)
     if (percent == 1) then
       if (showWhenDone) then
         obj:show()
       else
         obj:hide()
       end
     elseif (config.even) then
       obj:show()
     else
       obj:hide()
     end
  end

  local times = 3 
  local delta = 0.1
  vimouse.repeatCallback(times, delta, callback)
end

function vimouse.testTween()
end

function vimouse.getGridForScreen1(s)
    local NL = "\n"
    local img = ""
    local rowCount = 1000

    local rect = s:fullFrame()
    local rowCount = rect.w;

    local markers = {
          "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K",
          "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "a", "b", "c", "d", "e",
          "f", "g", "h", "i", "j", "k", "l", "m", "n", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"
    }

    local base = string.rep(".", rowCount - 2);
    local line = "." .. base .. "." .. NL

    img = img .. "1" .. base .. "2" .. NL 
    img = img .. "5" .. base .. "." .. NL 
    img = img .. string.rep(line, rowCount-2)
    img = img .. "4" .. base .. "3" .. NL

    img = "ASCII:" .. img

    local result = hs.drawing.image({x = 0, y = 0, h = rowCount, w = rowCount},
                            hs.image.imageFromASCII(img, {{
                                      strokeColor = BASE_COLOR,
                                      fillColor   = {alpha = 0},
                                      strokeWidth = 1,
                                      shouldClose = false,
                                      antialias = false,
                                  }}))

    --result:setAlpha(MONITOR_LABEL_ALPHA)
    --result:show()

    --local r = hs.geometry.rect(0,0,50,50)
    --result.text(r, "hi there")

    return result
end

function vimouse.getCellSize()
    local s = vimouse.getCurrentScreen(s)
    local rect = s:fullFrame()
    local cellWidth = rect.w / NUM_COLS
    local cellHeight = rect.h / NUM_ROWS
    local result = {w=cellWidth, h=cellHeight}
    return result
end

function vimouse.getGridForScreen(s)
    local NL = "\n"
    local img = ""

    local rect = s:fullFrame()
    local rowCount = rect.w;
    local cellWidth = rect.w / NUM_COLS;
    local cellHeight = rect.h / NUM_ROWS;

    local grid = {}
    for x = 1, cellWidth do
      grid[x] = {}
      for y = 1, cellHeight do
        grid[x][y] = "."
      end
    end

    local markers = {
          "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K",
          "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "a", "b", "c", "d", "e",
          "f", "g", "h", "i", "j", "k", "l", "m", "n", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"
    }

    local base = string.rep(".", rowCount - 2);
    local line = "." .. base .. "." .. NL

    img = img .. "1" .. base .. "2" .. NL 
    img = img .. "5" .. base .. "." .. NL 
    img = img .. string.rep(line, rowCount-2)
    img = img .. "4" .. base .. "3" .. NL

    img = "ASCII:" .. img

    local result = hs.drawing.image({x = 0, y = 0, h = rowCount, w = rowCount},
                            hs.image.imageFromASCII(img, {{
                                      strokeColor = BASE_COLOR,
                                      fillColor   = {alpha = 0},
                                      strokeWidth = 1,
                                      shouldClose = false,
                                      antialias = false,
                                  }}))

    --result:setAlpha(MONITOR_LABEL_ALPHA)
    --result:show()

    --local r = hs.geometry.rect(0,0,50,50)
    --result.text(r, "hi there")

    return result
end

function vimouse.testTweenOld()
--[[
local properties = {}
local fadeTween = tween.new(2, properties, {bgcolor = {0,0,0}, fgcolor={255,0,0}}, 'linear')
    //fadeTween:update(dt)
    vimouse.mouseCircleTimer = hs.timer.doAfter(1, function() 
      vimouse.hideBigCursor()
    end)
]]--

  local duration = 4
  local music = { volume = 0, path = "path/to/file.mp3" }
  local musicTween = tween.new(duration, music, {volume = 5}, 'linear')

  local callback = function (percent, t)
     vimouse.w('p:',percent)
     vimouse.w('v:',music.volume)
     musicTween:update(percent)
  end
  local delta = 0.1
  local times = duration / delta
  vimouse.repeatCallback(times, delta, callback)
end

vimouse.bindKeys()
vimouse.createMouseCursor()
vimouse.createMouseCursorGrid()
vimouse.recreateGridsForEachMonitor()

startWatchingForMonitorChanges()
--console.clearConsole()
--vimouse.showBrowser()

return vimouse
