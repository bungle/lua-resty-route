local encode       = require "cjson.safe".encode
local setmetatable = setmetatable
local create       = coroutine.create
local resume       = coroutine.resume
local status       = coroutine.status
local select       = select
local type         = type
local ngx          = ngx
local log          = ngx.log
local redirect     = ngx.redirect
local exit         = ngx.exit
local exec         = ngx.exec
local header       = ngx.header
local print        = ngx.print
local OK           = ngx.OK
local ERR          = ngx.ERR
local HTTP_OK      = ngx.HTTP_OK
local HTTP_ERROR   = ngx.HTTP_INTERNAL_SERVER_ERROR
local function process(self, i, ok, ...)
    if not ok then
        return self:fail(...)
    elseif i == 3 and select(1, ...) then
        return self:done(...)
    end
end
local function finish(self, func, ...)
    for i=2,1,-1 do
        local a = self[i]
        local n = a.n
        for j=n,1,-1 do
            if status(a[j]) == "suspended" then
                process(self, i, resume(a[j]))
            end
        end
    end
    return func(...)
end
local router       = {}
router.__index = router
function router.new(application, routing, routes)
    local self = setmetatable({ application, routing, routes }, router)
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
    local c = self.context
    for i=1,3 do
        local a = self[i]
        local n = a.n
        for j=1,n do
            a[j] = create(a[j])
            process(self, i, resume(a[j], c, method, location))
        end
    end
end
function router:render(content, context)
    local template = self.context.template
    if template then
        template.render(content, context or self.context)
    else
        print(content)
    end
    self:done()
end
function router:json(data)
    if type(data) == "table" then
        data = encode(data)
    end
    header.content_type = "application/json"
    print(data)
    self:done()
end
return router