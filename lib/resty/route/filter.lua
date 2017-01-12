local require      = require
local matcher      = require "resty.route.matcher"
local append       = require "resty.route.append"
local routable     = matcher.routable
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
        append(self[2], func, method, pattern)
    elseif pattern then
        if routable(method) then
            append(self[2], pattern, nil, method)
        else
            if routable(pattern) then
                return function(filters)
                    append(self[2], filters, method, pattern)
                    return self
                end
            end
            append(self[1], pattern, method)
        end
    else
        if routable(method) then
            return function(filters)
                append(self[1], filters, nil, method)
                return self
            end
        end
        append(self[2], method)
    end
    return self
end
return filter