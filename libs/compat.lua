local lib = {}

local expect
do
    local h = fs.open("rom/modules/main/cc/expect.lua", "r")
    local f, err = loadstring(h.readAll(), "@/rom/modules/main/cc/expect.lua")
    h.close()

    if not f then error(err) end
    expect = f().expect
end

function lib.setupENV(win)
    local expect = dofile("rom/modules/main/cc/expect.lua").expect

    local native = term.native and term.native() or term
    local redirectTarget = native

    local function wrap(_sFunction)
        return function(...)
            return redirectTarget[_sFunction](...)
        end
    end

    local term = {}

    --- Redirects terminal output to a monitor, a [`window`], or any other custom
    -- terminal object. Once the redirect is performed, any calls to a "term"
    -- function - or to a function that makes use of a term function, as [`print`] -
    -- will instead operate with the new terminal object.
    --
    -- A "terminal object" is simply a table that contains functions with the same
    -- names - and general features - as those found in the term table. For example,
    -- a wrapped monitor is suitable.
    --
    -- The redirect can be undone by pointing back to the previous terminal object
    -- (which this function returns whenever you switch).
    --
    -- @tparam Redirect target The terminal redirect the [`term`] API will draw to.
    -- @treturn Redirect The previous redirect object, as returned by
    -- [`term.current`].
    -- @since 1.31
    -- @usage
    -- Redirect to a monitor on the right of the computer.
    --
    --     term.redirect(peripheral.wrap("right"))
    term.redirect = function(target)
        expect(1, target, "table")
        if target == term or target == _G.term then
            error("term is not a recommended redirect target, try term.current() instead", 2)
        end
        for k, v in pairs(native) do
            if type(k) == "string" and type(v) == "function" then
                if type(target[k]) ~= "function" then
                    target[k] = function()
                        error("Redirect object is missing method " .. k .. ".", 2)
                    end
                end
            end
        end
        local oldRedirectTarget = redirectTarget
        redirectTarget = target
        return oldRedirectTarget
    end

    --- Returns the current terminal object of the computer.
    --
    -- @treturn Redirect The current terminal redirect
    -- @since 1.6
    -- @usage
    -- Create a new [`window`] which draws to the current redirect target.
    --
    --     window.create(term.current(), 1, 1, 10, 10)
    term.current = function()
        return redirectTarget
    end

    --- Get the native terminal object of the current computer.
    --
    -- It is recommended you do not use this function unless you absolutely have
    -- to. In a multitasked environment, [`term.native`] will _not_ be the current
    -- terminal object, and so drawing may interfere with other programs.
    --
    -- @treturn Redirect The native terminal redirect.
    -- @since 1.6
    term.native = function()
        return native
    end

    -- Some methods shouldn't go through redirects, so we move them to the main
    -- term API.
    for _, method in ipairs { "nativePaletteColor", "nativePaletteColour" } do
        term[method] = native[method]
        native[method] = nil
    end

    for k, v in pairs(native) do
        if type(k) == "string" and type(v) == "function" and rawget(term, k) == nil then
            term[k] = wrap(k)
        end
    end
    
    function write(sText)
        expect(1, sText, "string", "number")

        local w, h = term.getSize()
        local x, y = term.getCursorPos()

        local nLinesPrinted = 0
        local function newLine()
            if y + 1 <= h then
                term.setCursorPos(1, y + 1)
            else
                term.setCursorPos(1, h)
                term.scroll(1)
            end
            x, y = term.getCursorPos()
            nLinesPrinted = nLinesPrinted + 1
        end

        -- Print the line with proper word wrapping
        sText = tostring(sText)
        while #sText > 0 do
            local whitespace = string.match(sText, "^[ \t]+")
            if whitespace then
                -- Print whitespace
                term.write(whitespace)
                x, y = term.getCursorPos()
                sText = string.sub(sText, #whitespace + 1)
            end

            local newline = string.match(sText, "^\n")
            if newline then
                -- Print newlines
                newLine()
                sText = string.sub(sText, 2)
            end

            local text = string.match(sText, "^[^ \t\n]+")
            if text then
                sText = string.sub(sText, #text + 1)
                if #text > w then
                    -- Print a multiline word
                    while #text > 0 do
                        if x > w then
                            newLine()
                        end
                        term.write(text)
                        text = string.sub(text, w - x + 2)
                        x, y = term.getCursorPos()
                    end
                else
                    -- Print a word normally
                    if x + #text - 1 > w then
                        newLine()
                    end
                    term.write(text)
                    x, y = term.getCursorPos()
                end
            end
        end

        return nLinesPrinted
    end

    function print(...)
        local nLinesPrinted = 0
        local nLimit = select("#", ...)
        for n = 1, nLimit do
            local s = tostring(select(n, ...))
            if n < nLimit then
                s = s .. "\t"
            end
            nLinesPrinted = nLinesPrinted + write(s)
        end
        nLinesPrinted = nLinesPrinted + write("\n")
        return nLinesPrinted
    end

    function printError(...)
        local oldColour
        if term.isColour() then
            oldColour = term.getTextColour()
            term.setTextColour(colors.red)
        end
        print(...)
        if term.isColour() then
            term.setTextColour(oldColour)
        end
    end

    function read(_sReplaceChar, _tHistory, _fnComplete, _sDefault)
        expect(1, _sReplaceChar, "string", "nil")
        expect(2, _tHistory, "table", "nil")
        expect(3, _fnComplete, "function", "nil")
        expect(4, _sDefault, "string", "nil")

        term.setCursorBlink(true)

        local sLine
        if type(_sDefault) == "string" then
            sLine = _sDefault
        else
            sLine = ""
        end
        local nHistoryPos
        local nPos, nScroll = #sLine, 0
        if _sReplaceChar then
            _sReplaceChar = string.sub(_sReplaceChar, 1, 1)
        end

        local tCompletions
        local nCompletion
        local function recomplete()
            if _fnComplete and nPos == #sLine then
                tCompletions = _fnComplete(sLine)
                if tCompletions and #tCompletions > 0 then
                    nCompletion = 1
                else
                    nCompletion = nil
                end
            else
                tCompletions = nil
                nCompletion = nil
            end
        end

        local function uncomplete()
            tCompletions = nil
            nCompletion = nil
        end

        local w = term.getSize()
        local sx = term.getCursorPos()

        local function redraw(_bClear)
            local cursor_pos = nPos - nScroll
            if sx + cursor_pos >= w then
                -- We've moved beyond the RHS, ensure we're on the edge.
                nScroll = sx + nPos - w
            elseif cursor_pos < 0 then
                -- We've moved beyond the LHS, ensure we're on the edge.
                nScroll = nPos
            end

            local _, cy = term.getCursorPos()
            term.setCursorPos(sx, cy)
            local sReplace = _bClear and " " or _sReplaceChar
            if sReplace then
                term.write(string.rep(sReplace, math.max(#sLine - nScroll, 0)))
            else
                term.write(string.sub(sLine, nScroll + 1))
            end

            if nCompletion then
                local sCompletion = tCompletions[nCompletion]
                local oldText, oldBg
                if not _bClear then
                    oldText = term.getTextColor()
                    oldBg = term.getBackgroundColor()
                    term.setTextColor(colors.white)
                    term.setBackgroundColor(colors.gray)
                end
                if sReplace then
                    term.write(string.rep(sReplace, #sCompletion))
                else
                    term.write(sCompletion)
                end
                if not _bClear then
                    term.setTextColor(oldText)
                    term.setBackgroundColor(oldBg)
                end
            end

            term.setCursorPos(sx + nPos - nScroll, cy)
        end

        local function clear()
            redraw(true)
        end

        recomplete()
        redraw()

        local function acceptCompletion()
            if nCompletion then
                -- Clear
                clear()

                -- Find the common prefix of all the other suggestions which start with the same letter as the current one
                local sCompletion = tCompletions[nCompletion]
                sLine = sLine .. sCompletion
                nPos = #sLine

                -- Redraw
                recomplete()
                redraw()
            end
        end
        while true do
            local sEvent, param, param1, param2 = os.pullEvent()
            if sEvent == "char" then
                -- Typed key
                clear()
                sLine = string.sub(sLine, 1, nPos) .. param .. string.sub(sLine, nPos + 1)
                nPos = nPos + 1
                recomplete()
                redraw()

            elseif sEvent == "paste" then
                -- Pasted text
                clear()
                sLine = string.sub(sLine, 1, nPos) .. param .. string.sub(sLine, nPos + 1)
                nPos = nPos + #param
                recomplete()
                redraw()

            elseif sEvent == "key" then
                if param == keys.enter or param == keys.numPadEnter then
                    -- Enter/Numpad Enter
                    if nCompletion then
                        clear()
                        uncomplete()
                        redraw()
                    end
                    break

                elseif param == keys.left then
                    -- Left
                    if nPos > 0 then
                        clear()
                        nPos = nPos - 1
                        recomplete()
                        redraw()
                    end

                elseif param == keys.right then
                    -- Right
                    if nPos < #sLine then
                        -- Move right
                        clear()
                        nPos = nPos + 1
                        recomplete()
                        redraw()
                    else
                        -- Accept autocomplete
                        acceptCompletion()
                    end

                elseif param == keys.up or param == keys.down then
                    -- Up or down
                    if nCompletion then
                        -- Cycle completions
                        clear()
                        if param == keys.up then
                            nCompletion = nCompletion - 1
                            if nCompletion < 1 then
                                nCompletion = #tCompletions
                            end
                        elseif param == keys.down then
                            nCompletion = nCompletion + 1
                            if nCompletion > #tCompletions then
                                nCompletion = 1
                            end
                        end
                        redraw()

                    elseif _tHistory then
                        -- Cycle history
                        clear()
                        if param == keys.up then
                            -- Up
                            if nHistoryPos == nil then
                                if #_tHistory > 0 then
                                    nHistoryPos = #_tHistory
                                end
                            elseif nHistoryPos > 1 then
                                nHistoryPos = nHistoryPos - 1
                            end
                        else
                            -- Down
                            if nHistoryPos == #_tHistory then
                                nHistoryPos = nil
                            elseif nHistoryPos ~= nil then
                                nHistoryPos = nHistoryPos + 1
                            end
                        end
                        if nHistoryPos then
                            sLine = _tHistory[nHistoryPos]
                            nPos, nScroll = #sLine, 0
                        else
                            sLine = ""
                            nPos, nScroll = 0, 0
                        end
                        uncomplete()
                        redraw()

                    end

                elseif param == keys.backspace then
                    -- Backspace
                    if nPos > 0 then
                        clear()
                        sLine = string.sub(sLine, 1, nPos - 1) .. string.sub(sLine, nPos + 1)
                        nPos = nPos - 1
                        if nScroll > 0 then nScroll = nScroll - 1 end
                        recomplete()
                        redraw()
                    end

                elseif param == keys.home then
                    -- Home
                    if nPos > 0 then
                        clear()
                        nPos = 0
                        recomplete()
                        redraw()
                    end

                elseif param == keys.delete then
                    -- Delete
                    if nPos < #sLine then
                        clear()
                        sLine = string.sub(sLine, 1, nPos) .. string.sub(sLine, nPos + 2)
                        recomplete()
                        redraw()
                    end

                elseif param == keys["end"] then
                    -- End
                    if nPos < #sLine then
                        clear()
                        nPos = #sLine
                        recomplete()
                        redraw()
                    end

                elseif param == keys.tab then
                    -- Tab (accept autocomplete)
                    acceptCompletion()

                end

            elseif sEvent == "mouse_click" or sEvent == "mouse_drag" and param == 1 then
                local _, cy = term.getCursorPos()
                if param1 >= sx and param1 <= w and param2 == cy then
                    -- Ensure we don't scroll beyond the current line
                    nPos = math.min(math.max(nScroll + param1 - sx, 0), #sLine)
                    redraw()
                end

            elseif sEvent == "term_resize" then
                -- Terminal resized
                w = term.getSize()
                redraw()

            end
        end

        local _, cy = term.getCursorPos()
        term.setCursorBlink(false)
        term.setCursorPos(w + 1, cy)
        print()

        return sLine
    end

    local tAPIsLoading = {}

    local bAPIError = false

    local env = setmetatable({
        term = term,
        write = write,
        read = read,
        shell = shell,
        print = print,
        printError = printError
    }, { __index = _G })

    local function loadAPI(_sPath)
        expect(1, _sPath, "string")
        local sName = fs.getName(_sPath)
        if sName:sub(-4) == ".lua" then
            sName = sName:sub(1, -5)
        end
        if sName == "term" then
            return true
        end
        if tAPIsLoading[sName] == true then
            printError("API " .. sName .. " is already being loaded")
            return false
        end
        tAPIsLoading[sName] = true

        local tEnv = {}
        setmetatable(tEnv, { __index = env })
        local fnAPI, err = loadfile(_sPath, nil, tEnv)
        if fnAPI then
            local ok, err = pcall(fnAPI)
            if not ok then
                tAPIsLoading[sName] = nil
                return error("Failed to load API " .. sName .. " due to " .. err, 1)
            end
        else
            tAPIsLoading[sName] = nil
            return error("Failed to load API " .. sName .. " due to " .. err, 1)
        end

        local tAPI = {}
        for k, v in pairs(tEnv) do
            if k ~= "_ENV" then
                tAPI[k] = v
            end
        end
        env[sName] = tAPI
        tAPIsLoading[sName] = nil
        return true
    end

    local function load_apis(dir)
        if not fs.isDir(dir) then return end

        for _, file in ipairs(fs.list(dir)) do
            if file:sub(1, 1) ~= "." then
                local path = fs.combine(dir, file)
                if not fs.isDir(path) then
                    if not loadAPI(path) then
                        bAPIError = true
                    end
                end
            end
        end
    end

    load_apis("rom/apis")
    if http then load_apis("rom/apis/http") end
    if turtle then load_apis("rom/apis/turtle") end
    if pocket then load_apis("rom/apis/pocket") end
    env.shell = shell
    env.settings = settings
    env._ENV = env
    env._G = env
    env.http = http
    term.redirect(win)
    return env
end

local function generate_id(length)
    local id = ""
    for _ = 1, length do
        id = id .. string.char(math.random(97, 122))
    end
    return id
end

local function runInRuntime(func, win, close_handled)
    expect(1, func, "function")
    expect(2, win, "table")
    local co = coroutine.create(func)
    local winid = generate_id(40)
    local filter = nil
    local event_data = { n = 0 }
    local run = true
    function win.clicked(xc, yc, button)
        os.queueEvent("mouse_click_" .. winid, button, xc, yc, winid)
    end

    function win.released(xc, yc, button)
        os.queueEvent("mouse_up_" .. winid, button, xc, yc, winid)
    end

    function win.dragged(xc, yc, button)
        os.queueEvent("mouse_drag_" .. winid, button, xc, yc, winid)
    end

    function win.scrolled(dir, xc, yc)
        os.queueEvent("mouse_scroll_" .. winid, dir, xc, yc, winid)
    end

    function win.char(ch)
        os.queueEvent("char_" .. winid, ch, winid)
    end

    function win.key(key, is_held)
        os.queueEvent("key_" .. winid, key, is_held, winid)
    end

    function win.key_up(key)
        os.queueEvent("key_up_" .. winid, key, winid)
    end

    function win.resized()
        os.queueEvent("term_resize_"..winid, winid)
    end

    if close_handled then
        function win.closeRequested()
            run = false
        end
    end

    local function escape_lua_pattern(s)
        -- magic chars: ( ) . % + - * ? [ ^ $ ]
        return (s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
    end

    local start = true
    while run and coroutine.status(co) ~= "dead" do
        if event_data.n > 0 or start then
            local ok, msg = coroutine.resume(co, table.unpack(event_data, 1, event_data.n))
            start = false
            if ok then
                filter = msg
            else
                error(msg)
            end
        end
        local data = table.pack(os.pullEvent())
        data[1] = data[1]:gsub(escape_lua_pattern "_" .. winid, "")
        event_data = { n = 0 }
        if data[1] == filter or filter == nil or data[1] == "terminated" then
            if data[1] == "char" then
                if data[#data] == winid then
                    data.n = data.n - 1
                    event_data = data
                end
            elseif data[1] == "key" then
                if data[#data] == winid then
                    data.n = data.n - 1
                    event_data = data
                end
            elseif data[1] == "mouse_click" then
                if data[#data] == winid then
                    data.n = data.n - 1
                    event_data = data
                end
            elseif data[1] == "mouse_drag" then
                if data[#data] == winid then
                    data.n = data.n - 1
                    event_data = data
                end
            elseif data[1] == "key_up" then
                if data[#data] == winid then
                    data.n = data.n - 1
                    event_data = data
                end
            elseif data[1] == "mouse_up" then
                if data[#data] == winid then
                    data.n = data.n - 1
                    event_data = data
                end
            elseif data[1] == "mouse_scroll" then
                if data[#data] == winid then
                    data.n = data.n - 1
                    event_data = data
                end
            elseif data[1] == "term_resize" then
                if data[#data] == winid then
                    data.n = data.n - 1
                    event_data = data
                end
            else
                event_data = data
            end
        end
    end
end

function lib.runFunc(func, win, close_handled)
    runInRuntime(setfenv(func, lib.setupENV(win)), win, close_handled)
end

function lib.runFile(file, win, close_handled)
    local func = loadfile(file)
    runInRuntime(setfenv(func, lib.setupENV(win)), win, close_handled)
end

return lib
