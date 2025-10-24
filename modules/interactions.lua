local threading = require("libs.threading")
local dragging = nil
local resizing = false
local offsetX, offsetY = 0, 0
local key = {}
local function bringtofront(indx)
    local win = _G.windows[indx]
    if win.alwaysOnTop or win.alwaysBelow then return end
    _G.windows[indx] = nil
    local temp = {}
    local top = {}
    local bottom = {}
    for _, i in pairs(_G.windows) do
        if i.alwaysOnTop then
            top[#top + 1] = i
        elseif i.alwaysBelow then
            temp[#temp + 1] = i
        else
            bottom[#bottom + 1] = i
        end
    end
    temp[#temp + 1] = win
    _G.windows = bottom
    for _, i in pairs(temp) do
        _G.windows[#_G.windows + 1] = i
    end
    for _, i in pairs(top) do
        _G.windows[#_G.windows + 1] = i
    end
end
while true do
    local data = { os.pullEvent() }
    if data[1] == "mouse_click" then
        for indx = #_G.windows, 1, -1 do
            local win = _G.windows[indx]
            if data[4] == 1 then
                break
            elseif win.x+win.w-1 == data[3] and win.y+win.h-1 == data[4] and win.decorations and win.resizable then
                dragging = win
                resizing = true
                bringtofront(indx)
            elseif ((win.y - 1 == data[4] and win.x + 1 <= data[3] and win.x + win.w >= data[3] and data[2] == 1 and win.decorations) or (win.y <= data[4] and win.x <= data[3] and win.y + win.h > data[4] and win.x + win.w > data[3] and key[keys["leftAlt"]] and win.draggable)) then
                dragging = win
                offsetX = win.x - data[3]
                offsetY = win.y - data[4]
                bringtofront(indx)
                break
            elseif win.y - 1 == data[4] and win.x == data[3] and win.decorations then
                threading.addThread(function() win.closeRequested() end)
                bringtofront(indx)
                break
            elseif win.y <= data[4] and win.x <= data[3] and win.y + win.h > data[4] and win.x + win.w > data[3] then
                threading.addThread(function() win.clicked(data[3] - win.x + 1, data[4] - win.y + 1, data[2]) end)
                bringtofront(indx)
                break
            end
        end
    elseif data[1] == "mouse_drag" then
        if data[2] == 1 and dragging then
            if resizing then
                dragging.w = math.max(data[3] - dragging.x + 1,dragging.min_w)
                dragging.h = math.max(data[4] - dragging.y + 1,dragging.min_h)
                threading.addThread(function()dragging.resized(dragging.w,dragging.h)end)
            else
                dragging.x = data[3] + offsetX
                dragging.y = math.max(data[4],2) + offsetY
            end
        else
            for indx = #_G.windows, 1, -1 do
                local win = _G.windows[indx]
                if win.y <= data[4] and win.x <= data[3] and win.y + win.h > data[4] and win.x + win.w > data[3] then
                    threading.addThread(function() win.dragged(data[3] - win.x + 1, data[4] - win.y + 1, data[2]) end)
                    bringtofront(indx)
                    break
                end
            end
        end
    elseif data[1] == "mouse_up" then
        if data[2] == 1 and dragging then
            dragging = nil
            resizing = false
        else
            for indx = #_G.windows, 1, -1 do
                local win = _G.windows[indx]
                if win.y <= data[4] and win.x <= data[3] and win.y + win.h > data[4] and win.x + win.w > data[3] then
                    threading.addThread(function() win.released(data[3] - win.x + 1, data[4] - win.y + 1, data[2]) end)
                    bringtofront(indx)
                    break
                end
            end
        end
    elseif data[1] == "mouse_scroll" then
        for indx = #_G.windows, 1, -1 do
            local win = _G.windows[indx]
            if win.y <= data[4] and win.x <= data[3] and win.y + win.h > data[4] and win.x + win.w > data[3] then
                threading.addThread(function() win.scrolled(data[2], data[3] - win.x + 1, data[4] - win.y + 1) end)
                break
            end
        end
    elseif data[1] == "key" then
        key[data[2]] = true
        if _G.windows[#_G.windows] then
            threading.addThread(function() _G.windows[#_G.windows].key(data[2], data[3]) end)
        end
    elseif data[1] == "char" then
        if _G.windows[#_G.windows] then
            threading.addThread(function() _G.windows[#_G.windows].char(data[2]) end)
        end
    elseif data[1] == "key_up" then
        key[data[2]] = false
        if _G.windows[#_G.windows] then
            threading.addThread(function() _G.windows[#_G.windows].key_up(data[2]) end)
        end
    end
end
