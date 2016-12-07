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
local dofile = dofile
local ipairs = ipairs
local assert = assert
local pcall = pcall
local sub = string.sub
local var = ngx.var
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
function route:fs(path, location)
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
    local ok, lfs = pcall(require, "syscall.lfs")
    if not ok then
        ok, lfs = pcall(require, "lfs")
    end
    assert(ok, "Lua file system (LFS) library was not found")
    local dirs = {}
    for file in lfs.dir(path) do
        if file ~= "." and file ~= ".." then
            local f = path .. "/" .. file
            local mode = lfs.attributes(f).mode
            if mode == "directory" then
                dirs[#dirs+1] = { f, location .. "/" .. file }
            elseif mode == "file" or mode == "link" and sub(file, -4) == ".lua" then
                local found = false
                local base = sub(file, 1, #file - 4)
                for _, handler in ipairs(handlers) do
                    local h = "@" .. handler
                    if sub(base, -#h) == h then
                        found = true
                        local b = sub(base, 1, #base - #h - 1)
                        local l = "=*/"
                        if location ~= "" then
                            l = l .. location
                            if b ~= "index" then
                                l = l .. "/" .. b
                            end
                        elseif b ~= "index" then
                            l = l .. base
                        end
                        self(handler, l, dofile(f))
                        break
                    end
                end
                if not found then
                    local l = "=*/"
                    if location ~= "" then
                        l = l .. location
                        if base ~= "index" then
                            l = l .. "/" .. base
                        end
                    else
                        if base ~= "index" then
                            l = l .. base
                        end
                    end
                    self(l, dofile(f))
                end
            end
        end
    end
    for _, dir in ipairs(dirs) do
        self:fs(dir[1], dir[2])
    end
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
