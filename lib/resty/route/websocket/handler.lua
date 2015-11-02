local server       = require "resty.websocket.server"
local setmetatable = setmetatable
local ngx          = ngx
local var          = ngx.var
local kill         = ngx.thread.kill
local spawn        = ngx.thread.spawn
local sub          = string.sub
local ipairs       = ipairs

local mt, handler = {}, {}

function mt:__call(self, route, ...)
    local self = setmetatable(self, handler)
    self:upgrade()
    local websocket, err = server:new{
        max_payload_len = 65535,
        send_masked     = false,
        timeout         = 5000
    }
    if not websocket then
        route:error(err)
    end
    self.route = route
    self.websocket = websocket
    self:connect()
    local d, t, err = websocket:recv_frame()
    while not websocket.fatal do
        if not t then
            t = "unknown"
        end
        if self[t] then
            self[t](self, d)
        end
        d, t, err = websocket:recv_frame()
    end
    --return route:error(err)
end

handler.__index = handler

function handler:upgrade()
    local host = var.host
    local s =  #var.scheme + 4
    local e = #host + s - 1
    if sub(var.http_origin or "", s, e) ~= host then
        return self.route:forbidden()
    end
end

function handler:connect() end
function handler:continuation() end
function handler:text() end
function handler:binary() end
function handler:close()
    local threads = self.threads
    if threads then
        for _, v in ipairs(self.threads) do
            kill(v)
        end
    end
    local b, e = self.websocket:send_close()
    return b and self.route:ok() or self.route:error(e)
end

function handler:ping()
    local b, e = self.websocket:send_pong()
    if not b then return self.route:error(e) end
end

function handler:pong() end
function handler:unknown() end
function handler:send(text)
    local b, e = self.websocket:send_text(text)
    if not b then return self.route:error(e) end
end
function handler:spawn(...)
    if not self.threads then
        self.threads = {}
    end
    self.threads[#self.threads+1] = spawn(...)
end

return setmetatable(handler, mt)