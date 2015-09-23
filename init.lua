local screen = require 'hs.screen'
local log = require'hs.logger'.new('vimouse')
local vimouse = {}
local NUM_ROWS = 10
local NUM_COLS = 10
local grids = {}
local phrase = ""
local vimModifier = {"ctrl"}

-- Convert from table to CSV string
function toCSV (tt)
  local s = ""
  for _,p in ipairs(tt) do  
    s = s .. "," .. escapeCSV(p)
  end
  return string.sub(s, 2)      -- remove first comma
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
  local screen = hs.window.focusedWindow():screen():fullFrame()
  vimouse.moveMouse(screen.x + col*delta, screen.y + row*delta)
end

function vimouse.processKey(key)
  phrase = phrase .. key
  hs.alert.show("Pressed " .. key) 

  hs.alert.show("Phrase " .. phrase) 
  if (string.len(phrase) == 2) then
    hs.alert.show("ACTION " .. phrase) 
    vimouse.processAction(phrase)
    phrase = ""
  end
end

function vimouse.bindKey(key)
  KEYS:bind({}, key, function()
    vimouse.processKey(key)
  end)
end

function vimouse.bindKeys()
    local keys = {"A", "S", "D", "F", "G", "Q", "W", "E", "R", "T"}
    for _,key in ipairs(keys) do  
      vimouse.bindKey(key)
    end
end
vimouse.bindKeys()

vimouse.mouseCircle = nil
vimouse.mouseCircleTimer = nil
vimouse.gridVisible = true

function vimouse.toggle()
    if (vimouse.gridVisible) then
      hs.vimouse.show()
    else
      hs.vimouse.hide()
    end

    vimouse.gridVisible = not vimouse.gridVisible
end

function vimouse.doHide()
    --vimouse.deleteGridForEachMonitor()
    vimouse.toggleGridVisibility(grids, false)

    -- Delete an existing highlight if it exists
    if vimouse.mouseCircle then
        vimouse.mouseCircle:delete()
        if vimouse.mouseCircleTimer then
            vimouse.mouseCircleTimer:stop()
        end
    end
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

function vimouse.iDiv(a,b)
  local c = (a - a % b) / b
  return c
end

function vimouse.drawGridInFrame(cols,rows,f)
  log.w('Screen.f', cols,rows, f.w, f.h)
  local result = {}
  local width = vimouse.iDiv(f.w,rows)
  local height = vimouse.iDiv(f.h,cols)
  local cell

  for i=1,rows do
    for j=1,cols do
      local x = f.x + (i-1) * width
      local y = f.y + (j-1) * height
      cell = vimouse.createCell(x,y,width,height)
      table.insert(result, cell)
      --log.w('x,y,top,right', x,y,x+width,y+height)
    end
  end

  return result
end

function vimouse.createGridForEachMonitor()
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

function vimouse.createCell(x,y,w,h)
    --vimouse.mouseCircle = hs.drawing.rectangle(hs.geometry.rect(ptMouse.x-40, ptMouse.y-40, 80, 80))
    local result = hs.drawing.rectangle(hs.geometry.rect(x,y,w,h))
    result:setStrokeColor({["red"]=1,["blue"]=0,["green"]=0,["alpha"]=1})
    result:setFill(false)
    result:setStrokeWidth(1)
    --result:show()
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
  hs.notify.new({title="Hammerspoon", alwaysPresent=true, autoWithdraw=true, informativeText="Hello World"}):send():release()
    hs.mouse.setAbsolutePosition(ptMouse)
    --hs.alert.show("mouse:" .. toCSV(ptMouse))
end

function vimouse.show()
    KEYS:enter()
    vimouse.doHide()
    vimouse.toggleGridVisibility(grids, true)

    -- Get the current co-ordinates of the mouse pointer
    local ptMouse
    ptMouse = hs.mouse.getAbsolutePosition()

    --hs.alert.show("mouse:" .. toCSV(ptMouse))
    hs.alert.show("mouse:" .. ptMouse.x .. " " .. ptMouse.y)
    -- Prepare a big red circle around the mouse pointer
    local radius = 60
    vimouse.mouseCircle = hs.drawing.circle(hs.geometry.rect(ptMouse.x-radius, ptMouse.y-radius, radius*2, radius*2))
    --vimouse.mouseCircle = hs.drawing.rectangle(hs.geometry.rect(ptMouse.x-40, ptMouse.y-40, 80, 80))
    vimouse.mouseCircle:setStrokeColor({["red"]=1,["blue"]=0,["green"]=0,["alpha"]=1})
    vimouse.mouseCircle:setFill(false)
    vimouse.mouseCircle:setStrokeWidth(7)
    vimouse.mouseCircle:show()

    -- Set a timer to delete the circle after 3 seconds
    vimouse.mouseCircleTimer = hs.timer.doAfter(1, function() vimouse.mouseCircle:delete() end)
end

vimouse.createGridForEachMonitor()

return vimouse

