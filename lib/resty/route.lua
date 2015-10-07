local setmetatable = setmetatable
local setfenv = setfenv
local getfenv = getfenv
local select = select
local ipairs = ipairs
local pairs = pairs
local type = type
local unpack = table.unpack or unpack
local pack = table.pack
local ngx = ngx
local var = ngx.var
local redirect = ngx.redirect
local exit = ngx.exit
local exec = ngx.exec
local matchers = {}
if not pack then
    pack = function(...)
        return { n = select("#", ...), ...}
    end
end
local methods = {
    get     = "GET",
    head    = "HEAD",
    post    = "POST",
    put     = "PUT",
    patch   = "PATCH",
    delete  = "DELETE",
    options = "OPTIONS",
    link    = "LINK",
    unlink  = "UNLINK",
    trace   = "TRACE"
}
local verbs = {}
for k, v in pairs(methods) do
    verbs[v] = k
end
local function tofunction(e, f, m)
    local t = type(f)
    if t == "function" then
        return e and setfenv(f, setmetatable(e, { __index = getfenv(f) })) or f
    elseif t == "table" then
        if m then
            return tofunction(e, f[m])
        else
            return tofunction(e, f, "__call")
        end
    elseif t == "string" then
        return tofunction(e, require(f), m)
    end
    return nil
end
local function filter(route, location, pattern, self)
    local match = route.matcher
    if pattern then
        return (function(...)
            if select(1, ...) then
                return true, self(...)
            end
        end)(match(location, pattern))
    else
        return true, self()
    end
end
local function router(route, location, pattern, self)
    local match = route.matcher
    return (function(...)
        if select(1, ...) then
            return true, self(...)
        end
    end)(match(location, pattern))
end
local route = {}
route.__index = route
function route.new(opts)
    local m, t = ngx and "ngx" or "match", type(opts)
    if t == "table" then
        if opts.matcher then m = opts.matcher end
    end
    local self = setmetatable({
        matcher = require("resty.route.matchers." .. m)
    }, route)
    self.context = { route = self }
    return self
end
function route:with(matcher)
    if not matchers[matcher] then
        matchers[matcher] = require("resty.route.matchers." .. matcher)
    end
    return matchers[matcher]
end
function route:match(location, pattern)
    return self.matcher(location, pattern)
end
function route:filter(pattern, phase)
    local e = self.context
    if not self.filters then
        self.filters = {}
    end
    if not self.filters[phase] then
        self.filters[phase] = {}
    end
    local c = self.filters[phase]
    local t = type(pattern)
    if t == "string" then
        if methods[pattern] then
            if not c[pattern] then
                c[pattern] = {}
            end
            c = c[pattern]
            pattern = nil
        end
        return function(filters)
            if type(filters) == "table" then
                for _, func in ipairs(filters) do
                    local f = tofunction(e, func, phase)
                    c[#c+1] = function(location)
                        return filter(self, location, pattern, f)
                    end
                end
            else
                local f = tofunction(e, filters, phase)
                c[#c+1] = function(location)
                    return filter(self, location, pattern, f)
                end
            end
        end
    elseif t == "table" then
        for _, func in ipairs(pattern) do
            local f = tofunction(e, func, phase)
            c[#c+1] = function(location)
                return filter(self, location, nil, f)
            end
        end
    else
        local f = tofunction(e, pattern, phase)
        c[#c+1] = function(location)
            return filter(self, location, nil, f)
        end
    end
    return self
end
function route:before(pattern)
    return self:filter(pattern, "before")
end
function route:after(pattern)
    return self:filter(pattern, "after")
end
function route:__call(pattern, method, func)
    local e = self.context
    if not self.routes then
        self.routes = {}
    end
    local c = self.routes
    if func then
        if not c[method] then
            c[method] = {}
        end
        local c = c[method]
        local f = tofunction(e, func, method)
        c[#c+1] = function(location)
            return router(self, location, pattern, f)
        end
        return self
    else
        return function(routes)
            if type(routes) == "table" then
                for method, func in pairs(routes) do
                    if not c[method] then
                        c[method] = {}
                    end
                    local c = c[method]
                    local f = tofunction(e, func, method)
                    c[#c+1] = function(location)
                        return router(self, location, pattern, f)
                    end
                end
            else
                if not c[method] then
                    c[method] = {}
                end
                local c = c[method]
                local f = tofunction(e, routes, method)
                c[#c+1] = function(location)
                    return router(self, location, pattern, f)
                end
            end
            return self
        end
    end
end
for _, v in pairs(verbs) do
    route[v] = function(self, pattern, func)
        return self(pattern, v, func)
    end
end
function route:exit(status)
    -- TODO: should after filters be executed?
    return exit(status)
end
function route:exec(uri, args)
    -- TODO: should after filters be executed?
    return exec(uri, args)
end
function route:redirect(uri, status)
    -- TODO: should after filters be executed?
    return redirect(uri, status)
end
function route:websocket()
end
function route:error()
end
function route:notfound()
end
function route:to(location, method)
    method = method or "get"
    local results
    local filters = self.filters
    if filters then
        if filters.before then
            local before = filters.before
            for _, filter in ipairs(before) do
                filter(location)
            end
            local bm = before[method]
            if bm then
                for _, filter in ipairs(bm) do
                    filter(location)
                end
            end
        end
    end
    local routes = self.routes
    if routes then
        routes = routes[method]
        if routes then
            for _, route in ipairs(routes) do
                results = pack(route(location))
                if results.n > 0 then break end
            end
        end
    end
    if filters then
        local after = filters.after
        if after then
            local am = after[method]
            if am then
                for _, filter in ipairs(am) do
                    filter(location)
                end
            end
            for _, filter in ipairs(after) do
                filter(location)
            end
        end
    end
    return unpack(results, 1, results.n)
end
function route:dispatch()
    return self:to(var.uri, verbs[var.request_method])
end
return route