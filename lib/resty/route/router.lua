local require = require
local encode = require "cjson.safe".encode
local setmetatable = setmetatable
local ipairs = ipairs
local type = type
local ngx = ngx
local log = ngx.log
local ngx_redirect = ngx.redirect
local ngx_exit = ngx.exit
local ngx_exec = ngx.exec
local ngx_header = ngx.header
local ngx_print = ngx.print
local ngx_ok = ngx.OK
local ngx_err = ngx.ERR
local HTTP_OK = ngx.HTTP_OK
local HTTP_ERROR = ngx.HTTP_INTERNAL_SERVER_ERROR
local router = {}
router.__index = router
function router.new(routes, before, after)
    local self = setmetatable({ routes = routes, before = before, after = after }, router)
    self.context = setmetatable({ route = self }, { __index = self })
    self.context.context = self.context
    return self
end
function router:redirect(uri, status)
    return ngx_redirect(uri, status)
end
function router:exit(status)
    return ngx.headers_sent and ngx_exit(ngx_ok) or ngx_exit(status or ngx_ok)
end
function router:exec(uri, args)
    return ngx_exec(uri, args)
end
function router:done()
    return self:exit(HTTP_OK)
end
function router:fail(error)
    if error then
        log(ngx_err, error)
    end
    return self:exit(HTTP_ERROR)
end
function router:to(location, method)
    local routes = self.routes[method or "get"]
    local context = self.context
    local before = self.before or {}
    local filters = before.location or {}
    for _, filter in ipairs(filters) do
        filter(location, context)
    end
    filters = filters[method] or {}
    for _, filter in ipairs(filters) do
        filter(location, context)
    end
    if routes then
        for _, route in ipairs(routes) do
            if route(location, context) then
                break
            end
        end
    end
    local after = self.after
    filters = after.location[method] or {}
    for _, filter in ipairs(filters) do
        filter(location, context)
    end
    filters = after.location or {}
    for _, filter in ipairs(filters) do
        filter(location, context)
    end
end
function router:render(content, context)
    local template = self.context.template
    if template then
        template.render(content, context or self.context)
    else
        ngx_print(content)
    end
    self:done()
end
function router:json(data)
    if type(data) == "table" then
        data = encode(data)
    end
    ngx_header.content_type = "application/json"
    ngx_print(data)
    self:done();
end
return router