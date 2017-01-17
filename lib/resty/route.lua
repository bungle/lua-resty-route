local require      = require
local handler      = require "resty.route.handler"
local matcher      = require "resty.route.matcher"
local router       = require "resty.route.router"
local filter       = require "resty.route.filter"
local utils        = require "resty.route.utils"
local array        = utils.array
local object       = utils.object
local callable     = utils.callable
local routable     = matcher.routable
local resolve      = matcher.resolve
local setmetatable = setmetatable
local reverse      = string.reverse
local dofile       = dofile
local assert       = assert
local concat       = table.concat
local lower        = string.lower
local pairs        = pairs
local error        = error
local pcall        = pcall
local type         = type
local find         = string.find
local sub          = string.sub
local var          = ngx.var
local lfs
do
    local o, l = pcall(require, "syscall.lfs")
    if not o then o, l = pcall(require, "lfs") end
    if o then lfs = l end
end
local route = {}
function route:__index(n)
    if route[n] then
        return route[n]
    end
    return function(self, ...)
        return self(n, ...)
    end
end
function route.new()
    return setmetatable({ { n = 0 }, {}, filter = filter.new() }, route)
end
function route:match(location, pattern)
    local match, pattern = resolve(pattern)
    return match(location, pattern)
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
function route:__call(method, pattern, func)
    if func then
        handler(self[1], func, method, pattern)
    elseif pattern then
        if not routable(method) then
            return function(routes)
                handler(self[1], routes, method, pattern)
                return self
            end
        end
        handler(self[1], pattern, nil, method)
    else
        if routable(method) then
            return function(routes)
                handler(self[1], routes, nil, method)
                return self
            end
        elseif object(method) then
            for p, f in pairs(method) do
                if routable(p) then
                    handler(self[1], f, nil, p)
                end
            end
        else
            return function(p, f)
                if f then
                    handler(self[1], f, method, p)
                    return self
                end
                return function(f)
                    handler(self[1], f, method, p)
                    return self
                end
            end
        end
    end
    return self
end
function route:fs(path, location)
    assert(lfs, "Lua file system (LFS) library was not found")
    path = path or var.document_root
    if not path then return end
    if sub(path, -1) == "/" then
        path = sub(path, 1, #path - 1)
    end
    location = location or ""
    if sub(location, 1, 1) == "/" then
        location = sub(location, 2)
    end
    if sub(location, -1) == "/" then
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
    local c = self[2]
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
            return function(f)
                return self:on(code, f)
            end
        end
    end
end
function route:dispatch(location, method)
    router.new(self[1], self.filter[1], self.filter[2], self[2]):to(location or var.uri, lower(method or lower(var.http_upgrade) == "websocket" and "websocket" or var.request_method))
end
return route
