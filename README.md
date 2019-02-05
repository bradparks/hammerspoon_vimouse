# hammerspoon_vimouse
WORK IN PROGRESS: Move your mouse with your keyboard, using vi keystrokes and a visual grid

To use, save this repo to your hammerspoon extensions in a folder named `vimouse`. This is non standard, but is the way I did this when I originaly wrote it, and haven't fixed it yet ;-)

/Applications/Hammerspoon.app/Contents/Resources/extensions/hs/vimouse

then, in hammerspoons `~/.hammerspoon/init.lua`, put something like the following:
```
vimouse = require("vimouse")
hs.hotkey.bind({"cmd"}, "G", hs.vimouse.toggle)
```

Activate using `CMD+G` as a toggle to hide/show the grid

- Big Move using Ctrl+JKLM
- Small Move using Shift+JKLM
- Micro Move using Ctrl+Shift+JKLM
- Click using "Enter" key
- Right Click using "Ctrl+Enter" key
- Switch to monitors by number, using "M1", "M2", etc.

and grid movement can be done based off of letters displayed in the grid. For example, type "CF" and your cursor will move to column "C" and row "F", where the grid is based off of a 10x10 grid
