local lower = string.lower
local ngx = ngx
local var = ngx.var
return function(location, method)
    if not location then
        location = var.uri
    end
    if not method then
        if lower(var.http_upgrade) == "websocket" then
            return location, "websocket"
        end
        return location, lower(var.request_method)
    end
    return location, lower(method)
end