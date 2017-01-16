local require      = require
local handler      = require "resty.route.handler"
local routable     = require "resty.route.matcher".routable
local setmetatable = setmetatable
local filter       = {}
function filter:__index(n)
    if filter[n] then
        return filter[n]
    end
    return function(self, ...)
        return self(n, ...)
    end
end
function filter.new()
    return setmetatable({ { n = 0 }, { n = 0 } }, filter)
end
function filter:__call(method, pattern, func)
    if func then
        handler(self[1], func, method, pattern)
    elseif pattern then
        if routable(method) then
            handler(self[1], pattern, nil, method)
        else
            if routable(pattern) then
                return function(filters)
                    handler(self[1], filters, method, pattern)
                    return self
                end
            end
            handler(self[2], pattern, method)
        end
    else
        if routable(method) then
            return function(filters)
                handler(self[2], filters, nil, method)
                return self
            end
        end
        handler(self[2], method)
    end
    return self
end
return filter