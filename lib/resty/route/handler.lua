local require      = require
local require      = require
local resolve      = require "resty.route.matcher".resolve
local http         = require "resty.route.handlers.http"
local create       = coroutine.create
local ipairs       = ipairs
local type         = type
local handlers = {
    websocket = require "resty.route.handlers.websocket"
}
local function locator(h, m, p)
    if m then
        if p then
            local match, pattern = resolve(p)
            return function(method, location)
                if m == method then
                    return (function(ok, ...)
                        if ok then
                            return create(h), ...
                        end
                    end)(match(location, pattern))
                end
            end
        else
            return function(method)
                if m == method then
                    return create(h)
                end
            end
        end
    elseif p then
        local match, pattern = resolve(p)
        return function(_, location)
            return (function(ok, ...)
                if ok then
                    return create(h), ...
                end
            end)(match(location, pattern))
        end
    end
    return function()
        return create(h)
    end
end
local function push(array, pattern)
    return function(func, method)
        array.n = array.n + 1
        array[array.n] = locator(func, method, pattern)
    end
end
return function(array, func, method, pattern)
    if type(method) == "table" then
        for _, m in ipairs(method) do
            (handlers[m] or http)(push(array, pattern), func, m)
        end
    else
        (handlers[method] or http)(push(array, pattern), func, method)
    end
end