local methods = require "resty.route.methods"
local ipairs = ipairs
local handlers = { "websocket" }
for i, method in ipairs(methods) do
   handlers[i+1] = method
end
return handlers