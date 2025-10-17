local threading = require("libs.threading")
local dragging = nil
local offsetX, offsetY = 0, 0
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
            if win.y - 1 == data[4] and win.x + 1 <= data[3] and win.x + win.w >= data[3] and data[2] == 1 and win.decorations then
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
            dragging.x = data[3] + offsetX
            dragging.y = data[4] + offsetY
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
        if _G.windows[#_G.windows] then
            threading.addThread(function() _G.windows[#_G.windows].key(data[2], data[3]) end)
        end
    elseif data[1] == "char" then
        if _G.windows[#_G.windows] then
            threading.addThread(function() _G.windows[#_G.windows].char(data[2]) end)
        end
    elseif data[1] == "key_up" then
        if _G.windows[#_G.windows] then
            threading.addThread(function() _G.windows[#_G.windows].key_up(data[2]) end)
        end
    end
end
