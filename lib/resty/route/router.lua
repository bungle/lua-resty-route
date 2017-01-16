local encode         = require "cjson.safe".encode
local setmetatable   = setmetatable
local resume         = coroutine.resume
local status         = coroutine.status
local type           = type
local ngx            = ngx
local log            = ngx.log
local redirect       = ngx.redirect
local exit           = ngx.exit
local exec           = ngx.exec
local header         = ngx.header
local print          = ngx.print
local OK             = ngx.OK
local ERR            = ngx.ERR
local WARN           = ngx.WARN
local HTTP_OK        = ngx.HTTP_OK
local HTTP_ERROR     = ngx.HTTP_INTERNAL_SERVER_ERROR
local HTTP_NOT_FOUND = ngx.HTTP_NOT_FOUND
local function process(self, i, t, ok, ...)
    if ok then
        if i == 1 then return self:done(...) end
        if status(t) == "suspended" then
            local f = self[4]
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
local function go(self, i, location, method)
    self.location = location
    self.method = method
    local a = self[i]
    local n = a.n
    for j=1,n do
        execute(self, i, a[j](method, location))
    end
end
local function finish(self, func, ...)
    local f = self[4]
    local n = f.n
    for i=n,1,-1 do
        local t = f[i]
        f[i] = nil
        f.n = i - 1
        local ok, err = resume(t)
        if not ok then log(WARN, err) end
    end
    return func(...)
end
local router       = {}
router.__index = router
function router.new(routes, rf, af)
    local self = setmetatable({ routes, rf, af, { n = 0 } }, router)
    self.context = setmetatable({ route = self }, { __index = self })
    self.context.context = self.context
    return self
end
function router:redirect(uri, status)
    return finish(self, redirect, uri, status)
end
function router:exit(status)
    return finish(self, exit, status or OK)
end
function router:exec(uri, args)
    return finish(self, exec, uri, args)
end
function router:done()
    return self:exit(HTTP_OK)
end
function router:fail(error, code)
    if type(error) == "string" then
        log(ERR, error)
    end
    return self:exit(code or type(error) == "number" and error or HTTP_ERROR)
end
function router:to(location, method)
    method = method or "get"
    if self[3] then
        go(self, 3, location, method)
        self[3] = nil
    end
    go(self, 2, location, method)
    go(self, 1, location, method)
    self:fail(HTTP_NOT_FOUND)
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