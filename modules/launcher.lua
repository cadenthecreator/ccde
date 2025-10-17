local kb = require("libs.keybinds")
kb.register(kb.keybind():addKey(keys.leftAlt):addKey(keys.a), loadfile("apps/launcher.lua"))
