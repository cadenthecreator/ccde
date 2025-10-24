local lib = {}

local function add(t, v)
    for i = 1, #t + 1 do
        if t[i] == nil then
            t[i] = v
            return
        end
    end
end

function lib.reorder()
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
    _G.windows = bottom
    for _, i in pairs(temp) do
        _G.windows[#_G.windows + 1] = i
    end
    for _, i in pairs(top) do
        _G.windows[#_G.windows + 1] = i
    end
end

-- hex <-> color bit lookups (Lua 5.1 safe)
local HEX = "0123456789abcdef"
local hex_to_color, color_to_hex = {}, {}
for i = 1, 16 do
    local c = HEX:sub(i, i)
    local v = bit32 and bit32.lshift(1, i - 1) or 2 ^ (i - 1)
    hex_to_color[c] = v
    color_to_hex[v] = c
end

local function normalize_color(c)
    if color_to_hex[c] then return c end
    if type(c) ~= "number" or c < 1 or c > 0xffff then
        error("Colour out of range", 2)
    end
    -- match base's parse_color: coerce mask -> highest set bit (power-of-two)
    return 2 ^ math.floor(math.log(c, 2))
end

local function clamp(v, lo, hi) return (v < lo) and lo or ((v > hi) and hi or v) end

function lib.create(name, w, h, x, y, do_not_add)
    local sx,sy = term.getSize()
    if not x then x = sx/2-w/2 end
    if not y then y = sy/2-h/2 end
    w = math.floor(w + 0.5)
    h = math.floor(h + 0.5)
    x = math.floor(x + 0.5)
    y = math.floor(y + 0.5)
    -- x,y are metadata for you; renderer can use them
    local t = {
        name = name,
        w = w,
        h = h,
        min_w = 3,
        min_h = 3,
        x = x or 1,
        y = y or 2,

        -- column-major buffer: buffer[x][y] = {char, tc, bc}
        buffer = {},
        cursorX = 1,
        cursorY = 1,
        textColor = colors.white,
        bgColor = colors.black,
        cursorBlink = false,
        resizable = true,
        draggable = true,
        decorations = true,
        alwaysOnTop = false,
        alwaysBelow = false,
        closing = false,
        _palette = {}, -- optional local palette store
    }

    local function init_col(xi)
        if not t.buffer[xi] then
            t.buffer[xi] = {}
            for yy = 1, t.h do
                t.buffer[xi][yy] = { char = " ", tc = t.textColor, bc = t.bgColor }
            end
        end
    end

    function t.clear()
        for xi = 1, t.w do
            init_col(xi)
            for yy = 1, t.h do
                local cell = t.buffer[xi][yy]
                if not cell then cell = { char = " ", tc = t.textColor, bc = t.bgColor } end
                cell.char, cell.tc, cell.bc = " ", t.textColor, t.bgColor
            end
        end
        t.cursorX, t.cursorY = 1, 1
    end

    function t.current() return t end

    function t.redirect() end

    function t.clearLine()
        local y0 = t.cursorY
        if y0 < 1 or y0 > t.h then return end
        for xi = 1, t.w do
            init_col(xi)
            local cell = t.buffer[xi][y0]
            cell.char, cell.tc, cell.bc = " ", t.textColor, t.bgColor
        end
        -- base keeps cursorX unchanged
    end

    function t.getSize() return t.w, t.h end

    function t.setCursorPos(x0, y0)
        -- do NOT clamp; let writers clip like base window
        t.cursorX = math.floor(x0)
        t.cursorY = math.floor(y0)
    end

    function t.getCursorPos() return t.cursorX, t.cursorY end

    function t.setCursorBlink(b) t.cursorBlink = not not b end

    function t.getCursorBlink() return t.cursorBlink end

    function t.setTextColor(c) t.textColor = normalize_color(c) end

    t.setTextColour = t.setTextColor

    function t.getTextColor() return t.textColor end

    t.getTextColour = t.getTextColor

    function t.setBackgroundColor(c) t.bgColor = normalize_color(c) end

    t.setBackgroundColour = t.setBackgroundColor

    function t.getBackgroundColor() return t.bgColor end

    t.getBackgroundColour = t.getBackgroundColor

    function t.isColor()
        return term.native().isColor()
    end

    t.isColour = t.isColor

    -- Palette passthrough: store locally; renderer can apply
    function t.setPaletteColor(col, r, g, b)
        if type(r) == "number" and g and b then
            t._palette[col] = { r, g, b }
        elseif type(r) == "number" then
            -- assume 0xRRGGBB integer (no bitops)
            local v = r
            local R8 = math.floor(v / 65536) % 256
            local G8 = math.floor(v / 256) % 256
            local B8 = v % 256
            t._palette[col] = { R8 / 255, G8 / 255, B8 / 255 }
        end
    end

    t.setPaletteColour = t.setPaletteColor

    function t.getPaletteColor(col)
        local p = t._palette[col]
        if p then return p[1], p[2], p[3] end
        -- base always returns numbers; fall back to native
        return term.native().getPaletteColour(col)
    end

    t.getPaletteColour = t.getPaletteColor

    -- write/blit: mutate buffer with clipping; let cursor run past width
    function t.write(str)
        str = tostring(str)
        local y0 = t.cursorY
        for i = 1, #str do
            local x = t.cursorX + i - 1
            if x >= 1 and x <= t.w and y0 >= 1 and y0 <= t.h then
                init_col(x)
                local cell = t.buffer[x][y0]
                cell.char = str:sub(i, i)
                cell.tc, cell.bc = t.textColor, t.bgColor
            end
        end
        t.cursorX = t.cursorX + #str
    end

    function t.blit(text, textColors, bgColors)
        if type(text) ~= "string" then error("bad argument #1 (expected string)", 2) end
        if textColors and type(textColors) ~= "string" then error("bad argument #2 (expected string)", 2) end
        if bgColors and type(bgColors) ~= "string" then error("bad argument #3 (expected string)", 2) end
        if textColors and #textColors ~= #text then error("Arguments must be the same length", 2) end
        if bgColors and #bgColors ~= #text then error("Arguments must be the same length", 2) end

        textColors = textColors and textColors:lower() or nil
        bgColors   = bgColors and bgColors:lower() or nil

        local y0   = t.cursorY
        local n    = #text
        for i = 1, n do
            local x = t.cursorX + i - 1
            if x >= 1 and x <= t.w and y0 >= 1 and y0 <= t.h then
                init_col(x)
                local ch                    = text:sub(i, i)
                local tch                   = textColors and textColors:sub(i, i) or nil
                local bch                   = bgColors and bgColors:sub(i, i) or nil
                local tc                    = tch and hex_to_color[tch] or t.textColor
                local bc                    = bch and hex_to_color[bch] or t.bgColor

                local cell                  = t.buffer[x][y0] or { char = " ", tc = t.textColor, bc = t.bgColor }
                cell.char, cell.tc, cell.bc = ch, tc, bc
            end
        end
        t.cursorX = t.cursorX + n
    end

    -- scroll: supports positive (up) and negative (down)
    function t.scroll(n)
        n = math.floor(n or 1)
        if n == 0 then return end

        local absn = math.abs(n)
        if absn >= t.h then
            -- clear all rows to new empty lines with current colors
            for xi = 1, t.w do
                init_col(xi)
                for yy = 1, t.h do
                    local cell = t.buffer[xi][yy] or { char = " ", tc = t.textColor, bc = t.bgColor }
                    cell.char, cell.tc, cell.bc = " ", t.textColor, t.bgColor
                end
            end
            return
        end

        if n > 0 then
            -- move content up
            for xi = 1, t.w do
                init_col(xi)
                for yy = 1, t.h - n do
                    local dst, src = t.buffer[xi][yy], t.buffer[xi][yy + n]
                    dst.char, dst.tc, dst.bc = src.char, src.tc, src.bc
                end
                for yy = t.h - n + 1, t.h do
                    local cell = t.buffer[xi][yy] or { char = " ", tc = t.textColor, bc = t.bgColor }
                    cell.char, cell.tc, cell.bc = " ", t.textColor, t.bgColor
                end
            end
        else
            -- n < 0 : move content down
            local k = -n
            for xi = 1, t.w do
                init_col(xi)
                for yy = t.h, k + 1, -1 do
                    local dst, src = t.buffer[xi][yy], t.buffer[xi][yy - k]
                    dst.char, dst.tc, dst.bc = src.char, src.tc, src.bc
                end
                for yy = 1, k do
                    local cell = t.buffer[xi][yy]
                    cell.char, cell.tc, cell.bc = " ", t.textColor, t.bgColor
                end
            end
        end
    end

    -- input hooks (no-op; your UI can override)
    function t.clicked(xc, yc, button) end

    function t.released(xc, yc, button) end

    function t.dragged(xc, yc, button) end

    function t.scrolled(dir, xc, yc) end

    function t.char(ch) end

    function t.key(key, is_held) end

    function t.key_up(key) end

    function t.resized(w,h) end

    function t.closeRequested() t.closing = true end

    function t.close()
        t.closing = true
    end

    -- ---- Compatibility shims with base window (no rendering inside) ----

    function t.getPosition() return t.x, t.y end

    function t.reposition(nx, ny, nw, nh, _new_parent)
        nw = math.floor(nw + 0.5)
        nh = math.floor(nh + 0.5)
        nx = math.floor(nx + 0.5)
        ny = math.floor(ny + 0.5)
        if type(nx) ~= "number" or type(ny) ~= "number" then error("bad position", 2) end
        t.x, t.y = nx, ny

        if nw and nh then
            if type(nw) ~= "number" or type(nh) ~= "number" then error("bad size", 2) end
            local newbuf = {}
            for xi = 1, nw do
                newbuf[xi] = {}
                for yy = 1, nh do
                    local from =
                        (t.buffer[xi] and t.buffer[xi][yy]) and t.buffer[xi][yy]
                        or { char = " ", tc = t.textColor, bc = t.bgColor }
                    newbuf[xi][yy] = { char = from.char, tc = from.tc, bc = from.bc }
                end
            end
            t.buffer, t.w, t.h = newbuf, nw, nh
        end
    end

    function t.redraw() end -- renderer handles this elsewhere

    function t.setVisible(_) end

    function t.isVisible() return true end

    function t.restoreCursor() end

    -- initialize
    t.clear()
    if not do_not_add then
        add(_G.windows, t)
        lib.reorder()
    end
    return t
end

return lib
