local resolve = require "resty.route.matcher".resolve
local create  = coroutine.create
return function(h, m, p)
    if m then
        if p then
            local match, pattern = resolve(p)
            return function(method, location)
                if m == method then
                    return (function(ok, ...)
                        if ok then
                            return create(h), ...
                        end
                    end)(match(location, pattern))
                end
            end
        else
            return function(method)
                if m == method then
                    return create(h)
                end
            end
        end
    elseif p then
        local match, pattern = resolve(p)
        return function(_, location)
            return (function(ok, ...)
                if ok then
                    return create(h), ...
                end
            end)(match(location, pattern))
        end
    end
    return function()
        return create(h)
    end
end