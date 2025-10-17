local lib = {}

local function add(t, v)
    for i = 1, #t + 1 do
        if t[i] == nil then
            t[i] = v
            return i
        end
    end
end

function lib.addThread(func, env)
    env = setmetatable(env or {}, { __index = _ENV })
    env._ENV = env
    env._G = env
    local id = add(_G.threads, { co = coroutine.create(setfenv(func, env)) })
    os.queueEvent("thread", id)
    return id
end

function lib.addFromFile(file, env)
    local func = loadfile(file)
    env = setmetatable(env or {}, { __index = _ENV })
    local id = add(_G.threads, {
        co = coroutine.create(setfenv(func, env))
    })
    os.queueEvent("thread", id)
    return id
end

function lib.rmThread(id)
    _G.threads[id] = nil
end

return lib
