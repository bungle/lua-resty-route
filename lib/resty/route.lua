local require = require
local encode = require "cjson.safe".encode
local handler = require "resty.route.websocket.handler"
local setmetatable = setmetatable
local select = select
local ipairs = ipairs
local pairs = pairs
local type = type
local unpack = table.unpack or unpack
local pack = table.pack
local sub = string.sub
local ngx = ngx
local var = ngx.var
local log = ngx.log
local redirect = ngx.redirect
local header = ngx.header
local exit = ngx.exit
local exec = ngx.exec
local print = ngx.print
local ngx_ok = ngx.OK
local ngx_err = ngx.ERR
local http_ok = ngx.HTTP_OK
local http_error = ngx.HTTP_INTERNAL_SERVER_ERROR
local http_forbidden = ngx.HTTP_FORBIDDEN
local http_not_found = ngx.HTTP_NOT_FOUND
local matchers = {
    prefix = require "resty.route.matchers.prefix",
    equals = require "resty.route.matchers.equals",
    match  = require "resty.route.matchers.match",
    regex  = require "resty.route.matchers.regex",
    regexi = require "resty.route.matchers.regexi",
    simple = require "resty.route.matchers.simple",
}
local selectors = {
    ["="]  = matchers.equals,
    ["#"]  = matchers.match,
    ["~"]  = matchers.regex,
    ["~*"] = matchers.regexi,
    ["@"]  = matchers.simple
}
if not pack then
    pack = function(...)
        return { n = select("#", ...), ... }
    end
end
local methods = {
    get       = "GET",
    head      = "HEAD",
    post      = "POST",
    put       = "PUT",
    patch     = "PATCH",
    delete    = "DELETE",
    options   = "OPTIONS",
    link      = "LINK",
    unlink    = "UNLINK",
    trace     = "TRACE",
    websocket = "websocket"
}
local verbs = {}
for k, v in pairs(methods) do
    verbs[v] = k
end
local function tofunction(f, m)
    local t = type(f)
    if t == "function" then
        return f
    elseif t == "table" then
        if m then
            return tofunction(f[m])
        else
            return f
        end
    elseif t == "string" then
        return tofunction(require(f), m)
    end
    return nil
end
local function matcher(pattern)
    local s = selectors[sub(pattern, 1, 2)]
    if s then return s, sub(pattern, 3)  end
    s = selectors[sub(pattern, 1, 1)]
    if s then return s, sub(pattern, 2) end
    return matchers.prefix, pattern
end
local function websocket(context, location, pattern, self)
    local match, pattern = matcher(pattern)
    return (function(...)
        if select(1, ...) then
            return true, handler(self, context, ...)
        end
    end)(match(location, pattern))
end
local function router(context, location, pattern, self)
    local match, pattern = matcher(pattern)
    return (function(...)
        if select(1, ...) then
            return true, self(context, ...)
        end
    end)(match(location, pattern))
end
local function filter(context, location, pattern, self)
    if pattern then
        return router(context, location, pattern, self)
    else
        return true, self(context)
    end
end
local function runfilters(location, method, filters)
    if filters then
        for _, filter in ipairs(filters) do
            filter(location)
        end
        local mfilters = filters[method]
        if mfilters then
            for _, filter in ipairs(mfilters) do
                filter(location)
            end
        end
    end
end
local route = {}
route.__index = route
function route.new()
    local self = setmetatable({}, route)
    self.context = setmetatable({ route = self }, { __index = self })
    self.context.context = self.context
    return self
end
function route:use(middleware)
    return tofunction("resty.route.middleware." .. middleware)(self.context)
end
function route:match(location, pattern)
    local match, pattern = matcher(pattern)
    return match(location, pattern)
end
function route:filter(pattern, phase)
    local context = self.context
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
                    c[#c+1] = function(location)
                        return filter(context, location, pattern, tofunction(func, phase))
                    end
                end
            else
                c[#c+1] = function(location)
                    return filter(context, location, pattern, tofunction(filters, phase))
                end
            end
        end
    elseif t == "table" then
        for _, func in ipairs(pattern) do
            c[#c+1] = function(location)
                return filter(context, location, nil, tofunction(func, phase))
            end
        end
    else
        c[#c+1] = function(location)
            return filter(context, location, nil, tofunction(pattern, phase))
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
    local context = self.context
    if not self.routes then
        self.routes = {}
    end
    local c = self.routes
    if func then
        if not c[method] then
            c[method] = {}
        end
        local c = c[method]
        if method == "websocket" then
            c[#c+1] = function(location)
                return websocket(context, location, pattern, tofunction(func))

            end
        else
            c[#c+1] = function(location)
                return router(context, location, pattern, tofunction(func, method))
            end
        end
        return self
    else
        return function(routes)
            if type(routes) == "table" then
                if method then
                    if not c[method] then
                        c[method] = {}
                    end
                    local c = c[method]
                    local f = tofunction(routes)
                    if method == "websocket" then
                        c[#c+1] = function(location)
                            return websocket(context, location, pattern, f)
                        end
                    else
                        c[#c+1] = function(location)
                            return router(context, location, pattern, f)
                        end
                    end
                else
                    for method, func in pairs(routes) do
                        if not c[method] then
                            c[method] = {}
                        end
                        local c = c[method]
                        if method == "websocket" then
                            c[#c+1] = function(location)
                                return websocket(context, location, pattern, tofunction(func))
                            end
                        else
                            c[#c+1] = function(location)
                                return router(context, location, pattern, tofunction(func, method))
                            end
                        end
                    end
                end
            else
                if not c[method] then
                    c[method] = {}
                end
                local c = c[method]
                if method == "websocket" then
                    c[#c+1] = function(location)
                        return websocket(context, location, pattern, tofunction(routes))
                    end
                else
                    c[#c+1] = function(location)
                        return router(context, location, pattern, tofunction(routes, method))
                    end
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
function route:exit(status, noaf)
    if not noaf then
        runfilters(self.location, self.method, self.filters and self.filters.after)
    end
    return ngx.headers_sent and exit(ngx_ok) or exit(status or ngx_ok)
end
function route:exec(uri, args, noaf)
    if not noaf then
        runfilters(self.location, self.method, self.filters and self.filters.after)
    end
    return exec(uri, args)
end
function route:redirect(uri, status, noaf)
    if not noaf then
        runfilters(self.location, self.method, self.filters and self.filters.after)
    end
    return redirect(uri, status)
end
function route:forbidden(noaf)
    return self:exit(http_forbidden, noaf)
end
function route:ok(noaf)
    return self:exit(http_ok, noaf)
end
function route:error(error, noaf)
    if error then
        log(ngx_err, error)
    end
    return self:exit(http_error, noaf)
end
function route:notfound(noaf)
    return self:exit(http_not_found, noaf)
end
function route:to(location, method)
    method = method or "get"
    self.location = location
    self.method = method
    local results
    local routes = self.routes
    if routes then
        routes = routes[method]
        if routes then
            for _, route in ipairs(routes) do
                local results = pack(route(location))
                if results.n > 0 then
                    return unpack(results, 1, results.n)
                end
            end
        end
    end
end
function route:render(content, context)
    local template = self.context.template
    if template then
        template.render(content, context or self.context)
    else
        print(content)
    end
    self:ok()
end
function route:json(data)
    if type(data) == "table" then
        data = encode(data)
    end
    header.content_type = "application/json"
    print(data)
    self:ok();
end
function route:dispatch()
    local location, method = var.uri, verbs[var.http_upgrade == "websocket" and "websocket" or var.request_method]
    runfilters(location, method, self.filters and self.filters.before)
    return self:to(location, method) and self:ok() or self:notfound()
end
return route
