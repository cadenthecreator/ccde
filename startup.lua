--os.pullEvent = os.pullEventRaw

local window = require("libs.window")
local nft = require "cc.image.nft"
local wrap = require("cc.strings").wrap
_G.threads = {}
_G.windows = {}
_G.keybinds = {}
local term = term.native()
local event = { n = 0 }
local function threads()
    for id, thr in pairs(_G.threads) do
        if thr then
            if coroutine.status(thr.co) ~= "dead" then
                if thr.filter == nil or thr.filter == event[1] or event[1] == "terminate" then
                    local ok, msg = coroutine.resume(thr.co, table.unpack(event, 1, event.n))
                    if not ok then
                        msg = tostring(msg)
                        local wrapped_lines = wrap(msg, 23)
                        local win = window.create("Error", 25, #wrapped_lines + 2)
                        for y, i in ipairs(wrapped_lines) do
                            win.setCursorPos(2, y + 1)
                            win.setTextColor(colors.red)
                            win.write(i)
                        end
                        _G.threads[id] = nil
                    else
                        thr.filter = msg
                    end
                end
            else
                _G.threads[id] = nil
            end
        end
    end
    event = { os.pullEventRaw() }
end

local function windows()
    term.setCursorBlink(false)
    for id, win in ipairs(_G.windows) do
        for cy = 1, win.h do
            term.setCursorPos(win.x, win.y + cy - 1)
            local line, fg, bg = "", "", ""
            for cx = 1, win.w do
                if win.buffer[cx] then
                    local cell = win.buffer[cx][cy]
                    if cell then
                        line = line .. cell.char
                        fg = fg .. ("0123456789abcdef"):sub(math.log(cell.tc, 2) + 1, math.log(cell.tc, 2) + 1)
                        bg = bg .. ("0123456789abcdef"):sub(math.log(cell.bc, 2) + 1, math.log(cell.bc, 2) + 1)
                    else
                        line = line .. " "
                        fg = fg .. "0"
                        bg = bg .. "f"
                    end
                else 
                    line = line .. " "
                    fg = fg .. "0"
                    bg = bg .. "f"
                end
            end
            term.blit(line, fg, bg)
        end
        if win.decorations then
            term.setCursorPos(win.x, win.y - 1)
            term.setTextColor(colors.white)
            term.setBackgroundColor(colors.blue)
            term.write(string.sub("X " .. win.name .. string.rep(" ", win.w - #win.name - 2),1,win.w))
            if win.resizable then
                term.setCursorPos(win.x+win.w-1,win.y+win.h-1)
                term.write("\127")
            end
        end
        term.setCursorPos(win.x + win.cursorX - 1, win.y + win.cursorY - 1)
        term.setCursorBlink(win.cursorBlink)
        if win.closing then
            _G.windows[id] = nil
        end
    end
    window.reorder()
end

local function desktop()
    local image = nft.load(".wallpaper.nft")
    local paint_image = paintutils.loadImage(".wallpaper.nfp")
    local w, h = term.getSize()
    term.setBackgroundColor(colors.white)
    term.clear()
    if image then
        nft.draw(image,1,1)
    elseif paint_image then
        paintutils.drawImage(paint_image,1,2)
    end
end

local function bars()
    local cx,cy = term.getCursorPos()
    local w, h = term.getSize()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.gray)
    term.clearLine()
    term.write(" "..((_G.windows[#_G.windows] or {name=""}).name or "").." ")
    local rightbar = ""
    if network and network.getID and network.getDistance and network.getID() ~= -1 then
        rightbar = "id: "..tostring(network.getID()).." dist: "..tostring(math.floor(network.getDistance()+0.5))
    end
    term.setCursorPos(w-(#rightbar),1)
    term.write(rightbar)
    term.setCursorPos(cx,cy)
end
local threading = require("libs.threading")
local compat = require("libs.compat")
for _, i in ipairs(fs.list("/modules")) do
    if not fs.isDir("/modules/" .. i) then
        threading.addFromFile("/modules/" .. i)
    end
end

local function render()
    while true do
        desktop()
        windows()
        bars()
        sleep(1 / 20)
    end
end

local function process()
    while true do
        threads()
    end
end

parallel.waitForAny(process, render)
