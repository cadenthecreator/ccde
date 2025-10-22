local window = require("libs.window")
local threading = require("libs.threading")
local x, y = term.getSize()
local win = window.create("Launcher", x / 3, y / 1.4, x / 2 - ((x / 3) / 2), y / 2 - ((y / 1.5) / 2))
win.decorations = false
win.alwaysOnTop = true
local apps = {}
-- tiny alphabetical boost based on the first A–Z letter in the name
local function alpha_boost(name, scale)
    scale = scale or 0.001 -- tune this: 0.001 ⇒ max boost ≈ 0.026 for 'a'
    name = string.lower(name or "")
    -- find first alphabetic char
    local i = name:find("%a")
    if not i then return 0 end
    local ch = name:sub(i, i)
    local byte = ch:byte()
    -- map a..z -> 1..26; non-letters -> 0 boost
    if byte < 97 or byte > 122 then return 0 end
    local pos = byte - 96     -- 1 for 'a', 26 for 'z'
    return (27 - pos) * scale -- 'a' highest, 'z' lowest
end

-- literal (plain) substring counter with optional overlap
local function count_sub(s, sub, overlap)
    if sub == "" then return 0 end
    local count, i = 0, 0
    while true do
        local j = string.find(s, sub, i + 1, true)
        if not j then break end
        count = count + 1
        i = overlap and j or (j + #sub - 1)
    end
    return count
end

local function score(app, search)
    local name = string.lower(app.name or "")
    local q    = string.lower(search or "")

    local s    = count_sub(name, q, true) * 2
    if app.tags then
        for _, tag in ipairs(app.tags) do
            s = s + count_sub(string.lower(tag), q, true)
        end
    end

    -- Optional extra nudge if the name starts with the query (nice UX)
    if q ~= "" and name:sub(1, #q) == q then
        s = s + 0.5
    end

    -- Alphabetical tiebreaker (very small)
    s = s + alpha_boost(app.name)

    return s
end
for _, f in ipairs(fs.list("/.apps")) do
    local file = fs.open(fs.combine("/.apps", f), "r")
    if file then
        local v = textutils.unserialise(file.readAll())
        if v and v.name and v.file then
            apps[#apps + 1] = v
        end
        file.close()
    end
end

local function clamp(v, lo, hi) return (v < lo) and lo or ((v > hi) and hi or v) end

sleep()

local search = ""
local scroll = 1
local runnning = true
function win.char(ch)
    search = search .. ch
end

function win.key(key)
    if key == keys.backspace then
        search = search:sub(1, #search - 1)
    elseif key == keys.up then
        scroll = clamp(scroll - 1, 1, #apps)
    elseif key == keys.down then
        scroll = clamp(scroll + 1, 1, #apps)
    elseif key == keys.enter then
        local app = apps[scroll]
        threading.addFromFile(app.file)
        runnning = false
    elseif key == keys.leftCtrl then
        runnning = false
    end
end

while runnning do
    table.sort(apps, function(a, b) return score(a, search) > score(b, search) end)
    win.setBackgroundColor(colors.gray)
    win.clear()
    for i, app in ipairs(apps) do
        if i == scroll then
            win.setBackgroundColor(colors.white)
            win.setTextColor(colors.black)
        else
            win.setBackgroundColor(colors.gray)
            win.setTextColor(colors.white)
        end
        win.setCursorPos(1, i)
        win.clearLine()
        win.write(app.name)
    end
    local _, y = win.getSize()
    win.setCursorPos(1, y)
    win.setTextColor(colors.white)
    win.setBackgroundColor(colors.black)
    win.clearLine()
    win.write(search)
    sleep()
end

win.close()
