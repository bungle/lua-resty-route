local var = ngx.var

return function(route)
    route.context.ajax = var.http_x_requested_with == "XMLHttpRequest"
end
