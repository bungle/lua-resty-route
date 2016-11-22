local matcher = require "resty.route.matcher".find
local select = select
return function(func, pattern)
    local match, pattern = matcher(pattern)
    return function(location, context)
        return (function(...)
            if select(1, ...) then
                return true, func(context, ...)
            end
        end)(match(location, pattern))
    end
end