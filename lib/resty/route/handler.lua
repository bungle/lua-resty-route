local require      = require
local require      = require
local http         = require "resty.route.handlers.http"
local utils        = require "resty.route.utils"
local resolve      = utils.resolve
local array        = utils.array
local create       = coroutine.create
local ipairs       = ipairs
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
local function push(a, pattern)
    return function(func, method)
        a.n = a.n + 1
        a[a.n] = locator(func, method, pattern)
    end
end
return function(a, func, method, pattern)
    if array(method) then
        for _, m in ipairs(method) do
            (handlers[m] or http)(push(a, pattern), func, m)
        end
    else
        (handlers[method] or http)(push(a, pattern), func, method)
    end
end