local require = require
local handlers = require "resty.route.handlers"
local matcher = require "resty.route.matcher"
local append = require "resty.route.append"
local routable = matcher.routable
local setmetatable = setmetatable
local ipairs = ipairs
local filters = {}
filters.__index = filters
function filters.new(phase)
    return setmetatable({ filters = { location = {} }, phase = phase }, filters)
end
function filters.before()
    return filters.new("before")
end
function filters.after()
    return filters.new("after")
end
function filters:__call(method, pattern, func)
    local phase = self.phase
    local c = self.filters
    if func then
        c = c.location
        append(c, func, phase, method, pattern)
    elseif pattern then
        if routable(method) then
            c = c.location
            append(c, pattern, nil, method, phase)
        else
            if routable(pattern) then
                c = c.location
                return function(filters)
                    append(c, filters, method, pattern, phase)
                    return self
                end
            end
            append(c, pattern, method, nil, phase)
        end
    else
        if routable(method) then
            c = c.location
            return function(filters)
                append(c, filters, nil, method, phase)
                return self
            end
        end
        append(c, method, nil, nil, phase)
    end
    return self
end
for _, method in ipairs(handlers) do
    filters[method] = function(self, pattern, func)
        return self(method, pattern, func)
    end
end
return filters