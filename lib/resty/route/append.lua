local require = require
local locator = require "resty.route.locator"
local handler = require "resty.route.handler"
local ipairs  = ipairs
local type    = type
local function push(c, func, method, pattern)
    local handler = handler(func, method)
    if handler then
        c.n = c.n + 1
        c[c.n] = locator(handler, method, pattern)
    end
end
return function(c, func, method, pattern)
    if type(func) == "table" and not func[method] then
        for _, f in ipairs(func) do
            push(c, f, method, pattern)
        end
    else
        push(c, func, method, pattern)
    end
end