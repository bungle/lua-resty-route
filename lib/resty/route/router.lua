local encode       = require "cjson.safe".encode
local setmetatable = setmetatable
local create       = coroutine.create
local resume       = coroutine.resume
local status       = coroutine.status
local yield        = coroutine.yield
local pcall        = pcall
local type         = type
local next         = next
local ngx          = ngx
local log          = ngx.log
local redirect     = ngx.redirect
local exit         = ngx.exit
local exec         = ngx.exec
local header       = ngx.header
local print        = ngx.print
local OK           = ngx.OK
local ERR          = ngx.ERR
local WARN         = ngx.WARN
local HTTP_200     = ngx.HTTP_OK
local HTTP_302     = ngx.HTTP_MOVED_TEMPORARILY
local HTTP_500     = ngx.HTTP_INTERNAL_SERVER_ERROR
local HTTP_404     = ngx.HTTP_NOT_FOUND
local function process(self, i, t, ok, ...)
    if ok then
        if i == 3 then return self:done(...) end
        if status(t) == "suspended" then
            local f = self[1]
            local n = f.n + 1
            f.n = n
            f[n] = t
        end
    else
        return self:fail(...)
    end
end
local function execute(self, i, t, ...)
    if t then process(self, i, t, resume(t, self.context, ...)) end
end
local function go(self, i)
    local a = self[i]
    local n = a.n
    for j=1,n do
        execute(self, i, a[j](self.method, self.location))
    end
end
local function finish(self, status, func, ...)
    if status then
        local t = self[2]
        if next(t) then
            local f
            if t[status] then
                f = t[status]
            elseif status == 499 and t.abort then
                f = t.abort
            elseif status >= 100 and status <= 199 and t.info then
                f = t.info
            elseif status >= 200 and status <= 299 and t.success then
                f = t.success
            elseif status >= 300 and status <= 399 and t.redirect then
                f = t.redirect
            elseif status >= 400 and status <= 499 and t["client error"] then
                f = t["client error"]
            elseif status >= 500 and status <= 599 and t["server error"] then
                f = t["server error"]
            elseif status >= 400 and status <= 599 and t.error then
                f = t.error
            elseif t[-1] then
                f = t[-1]
            end
            if f then
                local o, e = pcall(f, self.context, status)
                if not o then log(WARN, e) end
            end
        end
    end
    local f = self[1]
    local n = f.n
    for i=n,1,-1 do
        local t = f[i]
        f[i] = nil
        f.n = i - 1
        local o, e = resume(t)
        if not o then log(WARN, e) end
    end
    return func(...)
end
local router = { yield = yield }
router.__index = router
function router.new(...)
    local self = setmetatable({ { n = 0 }, ... }, router)
    self.context = setmetatable({ route = self }, { __index = self })
    self.context.context = self.context
    return self
end
function router:redirect(uri, status)
    status = status or HTTP_302
    return finish(self, status, redirect, uri, status)
end
function router:exit(status)
    status = status or OK
    return finish(self, status, exit, status)
end
function router:exec(uri, args)
    status = status or OK
    return finish(self, status, exec, uri, args)
end
function router:done()
    return self:exit(HTTP_200)
end
function router:abort()
    return self:exit(HTTP_200)
end
function router:fail(error, code)
    if type(error) == "string" then
        log(ERR, error)
    end
    return self:exit(code or type(error) == "number" and error or HTTP_500)
end
function router:to(location, method)
    method = method or "get"
    self.location = location
    self.method = method
    if self[5] then
        go(self, 5)
        self[5] = nil
    end
    go(self, 4)
    local named = self[3][location]
    if named then
        execute(self, 3, type(named) == "function" and create(named) or create(function(...) named(...) end))
    else
        go(self, 3)
    end
    self:fail(HTTP_404)
end
function router:render(content, context)
    local template = self.context.template
    if template then
        template.render(content, context or self.context)
    else
        print(content)
    end
    return self
end
function router:json(data)
    if type(data) == "table" then
        data = encode(data)
    end
    header.content_type = "application/json"
    print(data)
    return self
end
return router