local var = ngx.var

return function(route)
    if not not var.http_x_pjax then
        route.context.pjax = {
            container = var.http_x_pjax_container,
            version   = var.http_x_pjax_version
        }
    end
end