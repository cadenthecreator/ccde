local keybinds = {}
function keybinds.keybind()
    local keybind = { keys = {} }
    function keybind.addKey(self, key)
        assert(type(key) == "number", "expected number.. got " .. type(key))
        keybind.keys[#keybind.keys + 1] = key
        return self
    end

    return keybind
end

function keybinds.register(keybind, func)
    assert(type(keybind) == "table", "expected table for arg #1.. got " .. type(keybind))
    assert(type(func) == "function", "expected function for arg #2.. got " .. type(func))
    assert(keybind.keys ~= nil, "arg #1 is not a keybind")
    _G.keybinds[#_G.keybinds + 1] = { kb = keybind, func = func, pressed = false }
end

return keybinds
