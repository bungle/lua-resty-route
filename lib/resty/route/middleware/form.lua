local form = require "resty.validation".fields

return function(route)
    route.context.form = form
end
