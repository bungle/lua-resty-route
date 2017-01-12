local resolve = require "resty.route.matcher".resolve
return function(h, m, p)
    if m then
        if p then
            local match, pattern = resolve(p)
            return function(context, method, location)
                if m == method then
                    return (function(ok, ...)
                        if ok then
                            return true, h(context, ...)
                        end
                    end)(match(location, pattern))
                end
            end
        else
            return function(context, method, _)
                if m == method then
                    return true, h(context)
                end
            end
        end
    elseif p then
        local match, pattern = resolve(p)
        return function(context, _, location)
            return (function(ok, ...)
                if ok then
                    return true, h(context, ...)
                end
            end)(match(location, pattern))
        end
    end
    return h
end