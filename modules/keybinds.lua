local keystate = {}
local threading = require("libs.threading")
local function isEqual(t1, t2)
    if #t1 ~= #t2 then return false end
    for k = 1, #t1 do
        if t1[k] ~= t2[k] then return false end
    end
    return true
end
while true do
    local proto, key, is_held = os.pullEvent()
    if proto == "key" and not is_held then
        keystate[#keystate + 1] = key
    elseif proto == "key_up" then
        for k, v in ipairs(keystate) do
            if v == key then
                keystate[k] = nil
            end
        end
        local tempkeystate = {}
        for _, v in pairs(keystate) do
            tempkeystate[#tempkeystate + 1] = v
        end
        keystate = tempkeystate
    end
    for _, keybinding in ipairs(_G.keybinds) do
        if isEqual(keybinding.kb.keys, keystate) and not keybinding.pressed then
            threading.addThread(keybinding.func)
            keybinding.pressed = true
        elseif not isEqual(keybinding.kb.keys, keystate) then
            keybinding.pressed = false
        end
    end
end
