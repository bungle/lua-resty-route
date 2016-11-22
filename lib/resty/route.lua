local require = require
local handlers = require "resty.route.handlers"
local filters = require "resty.route.filters"
local matcher = require "resty.route.matcher"
local router = require "resty.route.router"
local locmet = require "resty.route.locmet"
local append = require "resty.route.append"
local routable = matcher.routable
local find = matcher.find
local setmetatable = setmetatable
local ipairs = ipairs
local route = {}
route.__index = route
function route.new()
    return setmetatable({ routes = {}, before = filters.before(), after = filters.after() }, route)
end
function route:match(location, pattern)
    local match, pattern = find(pattern)
    return match(location, pattern)
end
function route:__call(method, pattern, func)
    local c = self.routes
    if func then
        append(c, func, method, pattern)
    elseif pattern then
        if not routable(method) then
            return function(routes)
                append(c, routes, method, pattern)
                return self
            end
        end
        for _, v in ipairs(handlers) do
            append(c, pattern, v, method)
        end
    else
        return routable(method) and function(routes)
            for _, handler in ipairs(handlers) do
                append(c, routes, handler, method)
            end
            return self
        end or function(p, f)
            if f then
                append(c, f, method, p)
                return self
            end
            return function(f)
                append(c, f, method, p)
                return self
            end
        end
    end
    return self
end
function route:dispatch(location, method)
    location, method = locmet(location, method)
    local router = router.new(self.routes, self.before.filters, self.after.filters)
    local context = router.context
    local bf = self.before.filters
    local bm = bf[method] or {}
    for _, filter in ipairs(bf) do
        filter(context)
    end
    for _, filter in ipairs(bm) do
        filter(context)
    end
    router:to(location, method)
    local af = self.after.filters
    local am = af[method] or {}
    for _, filter in ipairs(am) do
        filter(context)
    end
    for _, filter in ipairs(af) do
        filter(context)
    end
end
for _, method in ipairs(handlers) do
    route[method] = function(self, pattern, func)
        return self(method, pattern, func)
    end
end
return route
