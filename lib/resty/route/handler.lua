local require = require
local http = require "resty.route.handlers.http"
local websocket = require "resty.route.handlers.websocket"
return function(func, method)
    return method == "websocket" and websocket(func) or http(func, method)
end