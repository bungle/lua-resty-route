local require      = require
local router       = require "resty.route.router"
local setmetatable = setmetatable
local getmetatable = getmetatable
local reverse      = string.reverse
local create       = coroutine.create
local select       = select
local rawget       = rawget
local dofile       = dofile
local assert       = assert
local error        = error
local concat       = table.concat
local unpack       = table.unpack or unpack
local ipairs       = ipairs
local pairs        = pairs
local lower        = string.lower
local floor        = math.floor
local pcall        = pcall
local type         = type
local find         = string.find
local byte         = string.byte
local max          = math.max
local sub          = string.sub
local var          = ngx.var
local S            = byte "*"
local H            = byte "#"
local E            = byte "="
local T            = byte "~"
local F            = byte "/"
local A            = byte "@"
local lfs
do
    local o, l = pcall(require, "syscall.lfs")
    if not o then o, l = pcall(require, "lfs") end
    if o then lfs = l end
end
local handlers = {
    websocket = require "resty.route.handlers.websocket"
}
local matchers = {
    prefix  = require "resty.route.matchers.prefix",
    equals  = require "resty.route.matchers.equals",
    match   = require "resty.route.matchers.match",
    regex   = require "resty.route.matchers.regex",
    simple  = require "resty.route.matchers.simple",
}
local selectors = {
    [E] = matchers.equals,
    [H] = matchers.match,
    [T] = matchers.regex,
    [A] = matchers.simple
}
local function location(l)
    return l or var.uri
end
local function method(m)
    return lower(m or lower(var.http_upgrade) == "websocket" and "websocket" or var.request_method)
end
local function array(t)
    if type(t) ~= "table" then return false end
    local m, c = 0, 0
    for k, _ in pairs(t) do
        if type(k) ~= "number" or k < 0 or floor(k) ~= k then return false end
        m = max(m, k)
        c = c + 1
    end
    return c == m
end
local function object(t)
    return type(t) == "table" and not(array(t))
end
local function callable(func)
    if type(func) == "function" then
        return true
    end
    local mt = getmetatable(func)
    return mt and mt.__call
end
local function routable(pattern)
    if type(pattern) ~= "string" then return false end
    local b = byte(pattern, 1, 1)
    return selectors[b] or S == b or F == b
end
local function resolve(pattern)
    local b = byte(pattern, 1, 1)
    if b == S then return matchers.prefix, sub(pattern, 2), true end
    local s = selectors[b]
    if s then
        if b == H or byte(pattern, 2, 2) ~= S then return s, sub(pattern, 2) end
        return s, sub(pattern, 3), true
    end
    return matchers.prefix, pattern
end
local function matcher(h, ...)
    if select(1, ...) then
        return create(h), ...
    end
end
local function locator(h, m, p)
    if m then
        if p then
            local match, pattern, insensitive = resolve(p)
            return function(method, location)
                if m == method then
                    return matcher(h, match(location, pattern, insensitive))
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
        local match, pattern, insensitive = resolve(p)
        return function(_, location)
            return matcher(h, match(location, pattern, insensitive))
        end
    end
    return function()
        return create(h)
    end
end
local function http(push, func, method)
    local t = type(func)
    if t == "function" then
        push(func, method)
    elseif t == "table" then
        if method then
            if callable(func[method]) then
                push(func[method], method)
            elseif callable(func) then
                push(func, method)
            elseif array(func) then
                for _, f in ipairs(func) do
                    if callable(f) then
                        push(f, method)
                    end
                end
            else
                error "Invalid HTTP handler"
            end
        else
            if callable(func) then
                push(func)
            elseif object(func) then
                for m, f in pairs(func) do
                    if type(m) == "string" and callable(f) then
                        push(f, m)
                    end
                end
            else
                error "Invalid HTTP handler"
            end
        end
    elseif t == "string" then
        local ok, func = pcall(require, func)
        if ok then
            http(push, func, method)
        end
    else
        error "Invalid HTTP handler"
    end
end
local function push(self, pattern)
    local a = self:array(pattern)
    return function(func, method)
        a.n = a.n + 1
        a[a.n] = locator(func, method, pattern)
    end
end
local function handle(self, method, pattern, func)
    if array(method) then
        for _, m in ipairs(method) do
            (handlers[m] or http)(push(self, pattern), func, m)
        end
    else
        (handlers[method] or http)(push(self, pattern), func, method)
    end
end
local function handler(self, ...)
    local n = select("#", ...)
    if n == 3 then
        handle(self, ...)
    elseif n == 2 then
        local method, pattern = ...
        if routable(method) then
            handle(self, nil, ...)
        elseif callable(pattern) then
            handle(self, method, nil, pattern)
        else
            return function(func)
                handle(self, method, pattern, func)
                return self
            end
        end
    elseif n == 1 then
        local method = ...
        if routable(method) then
            return function(func)
                handle(self, nil, method, func)
                return self
            end
        elseif callable(method) then
            handle(self, nil, nil, method)
        elseif object(method) then
            for pattern, func in pairs(method) do
                if routable(pattern) then
                    handle(self, nil, pattern, func)
                end
            end
        else
            return function(pattern, func)
                if func then
                    handle(self, method, pattern, func)
                else
                    return function(func)
                        handle(self, method, pattern, func)
                        return self
                    end
                end
                return self
            end
        end
    else
        error "Invalid number of arguments"
    end
    return self
end
local function index(self, n)
    local field = rawget(getmetatable(self), n)
    return field and field or function(self, ...)
        return self(n, ...)
    end
end
local filter = { __index = index, __call = handler }
function filter.new(...)
    return setmetatable({ ... }, filter)
end
function filter:array(pattern)
    return pattern and self[1] or self[2]
end
local route = { __index = index, __call = handler }
function route.new()
    local a, b, c, d = { n = 0 }, { n = 0 }, { n = 0 }, {}
    return setmetatable({ a, b, c, d, filter = filter.new(b, c) }, route)
end
function route:array()
    return self[1]
end
function route:match(location, pattern)
    local match, pattern, insensitive = resolve(pattern)
    return match(location, pattern, insensitive)
end
function route:clean(location)
    if type(location) ~= "string" or location == "" or location == "/" or location == "." or location == ".." then return "/" end
    local s = find(location, "/", 1, true)
    if not s then return "/" .. location end
    local i, n, t = 1, 1, {}
    while s do
        if i < s then
            local f = sub(location, i, s - 1)
            if f == ".." then
                n = n > 1 and n - 1 or 1
                t[n] = nil
            elseif f ~= "." then
                t[n] = f
                n = n + 1
            end
        end
        i = s + 1
        s = find(location, "/", i, true)
    end
    local f = sub(location, i)
    if f == ".." then
        n = n > 1 and n - 1 or 1
        t[n] = nil
    elseif f ~= "." then
        t[n] = f
        n = n + 1
    end
    return "/" .. concat(t, "/")
end
function route:use(...)
    return self.filter(...)
end
function route:fs(path, location)
    assert(lfs, "Lua file system (LFS) library was not found")
    path = path or var.document_root
    if not path then return end
    if byte(path, -1) == F then
        path = sub(path, 1, #path - 1)
    end
    location = location or ""
    if byte(location, 1, 1) == F then
        location = sub(location, 2)
    end
    if byte(location, -1) == F then
        location = sub(location, 1, #location - 1)
    end
    local dir = lfs.dir
    local attributes = lfs.attributes
    local dirs = { n = 0 }
    for file in dir(path) do
        if file ~= "." and file ~= ".." then
            local f = path .. "/" .. file
            local mode = attributes(f).mode
            if mode == "directory" then
                dirs.n = dirs.n + 1
                dirs[dirs.n] = { f, location .. "/" .. file }
            elseif mode == "file" or mode == "link" and sub(file, -4) == ".lua" then
                local b = sub(file, 1, #file - 4)
                local m
                local i = find(reverse(b), "@", 1, true)
                if i then
                    m = sub(b, -i+1)
                    b = sub(b, 1, -i-1)
                end
                local l = { "=*/" }
                if location ~= "" then
                    l[2] = location
                    if b ~= "index" then
                        l[3] = "/"
                        l[4] = b
                    end
                else
                    if b ~= "index" then
                        l[2] = b
                    end
                end
                self(m, concat(l), dofile(f))
            end
        end
    end
    for i=1, dirs.n do
        self:fs(dirs[i][1], dirs[i][2])
    end
    return self
end
function route:on(code, func)
    local c = self[4]
    if func then
        local t = type(func)
        if t == "function" then
            c[code] = func
        elseif t == "table" then
            if callable[func[code]] then
                c[code] = func[code]
            elseif callable(func) then
                c[code] = func
            else
                error "Invalid error handler"
            end
        else
            error "Invalid error handler"
        end
    else
        local t = type(code)
        if t == "function" then
            c[-1] = code
        elseif t == "table" then
            if callable(code) then
                c[-1] = code
            else
                for n, f in pairs(code) do
                    if callable(f) then
                        c[n] = f
                    end
                end
            end
        else
            return function(func)
                return self:on(code, func)
            end
        end
    end
end
function route:dispatch(l, m)
    router.new(unpack(self)):to(location(l), method(m))
end
return route
