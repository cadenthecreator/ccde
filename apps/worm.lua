local compat = require("libs.compat")
local window = require("libs.window")
local x, y = term.getSize()
local win = window.create("Worm", x / 1.4, y / 1.4, x / 2 - ((x / 1.4) / 2), y / 2 - ((y / 1.5) / 2))
win.resizable = false
sleep()
compat.runFile("/rom/programs/fun/worm.lua", win)
win.close()
