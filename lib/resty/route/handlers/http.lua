local require      = require
local getmetatable = getmetatable
local ipairs       = ipairs
local pairs        = pairs
local pcall        = pcall
local type         = type
local function callable(func)
    if type(func) == "function" then
        return true
    end
    local mt = getmetatable(func)
    return mt and mt.__call
end
local function http(push, func, method)
    local t = type(func)
    if t == "function" then
        push(func, method)
    elseif t == "table" then
        if method then
            if callable(func[method]) then
                push(func[method], method)
            elseif callable(func) then
                push(func, method)
            else
                for _, f in ipairs(func) do
                    if callable(f) then
                        push(f, method)
                    end
                end
            end
        else
            if callable(func) then
                push(func)
            else
                for m, f in pairs(func) do
                    if type(m) == "string" and callable(f) then
                        push(f, m)
                    end
                end
            end
        end
    elseif t == "string" then
        local ok, func = pcall(require, func)
        if ok then
            http(push, func, method)
        end
    end
end
return http