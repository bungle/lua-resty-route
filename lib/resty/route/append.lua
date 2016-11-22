local require = require
local locator = require "resty.route.locator"
local handler = require "resty.route.handler"
local ipairs = ipairs
local type = type
local function push(c, func, method, pattern, phase)
    local handler = handler(func, phase or method)
    if handler then
        if method then
            if not c[method] then
                c[method] = {}
            end
            c = c[method]
        end
        c[#c+1] = pattern and locator(handler, pattern) or handler
    end
end
return function(c, func, method, pattern, phase)
    if type(func) == "table" and not func[phase or method] then
        for _, func in ipairs(func) do
            push(c, func, method, pattern, phase)
        end
    else
        push(c, func, method, pattern, phase)
    end
end