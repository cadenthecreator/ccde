while true do
    local _, mb, x, y = os.pullEvent("mouse_scroll")
    print(x, y)
end
