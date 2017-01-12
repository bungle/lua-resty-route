local require = require
local type    = type
local function http(func, method)
    local t = type(func)
    if t == "function" then
        return func
    elseif t == "table" then
        if method then
            return http(func[method])
        else
            return func
        end
    elseif t == "string" then
        return http(require(func), method)
    end
    return nil
end
return http