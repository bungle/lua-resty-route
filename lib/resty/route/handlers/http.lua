local require      = require
local utils        = require "resty.route.utils"
local callable     = utils.callable
local object       = utils.object
local array        = utils.array
local ipairs       = ipairs
local pairs        = pairs
local pcall        = pcall
local error        = error
local type         = type
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
            elseif array(func) then
                for _, f in ipairs(func) do
                    if callable(f) then
                        push(f, method)
                    end
                end
            else
                error "Invalid HTTP handler"
            end
        else
            if callable(func) then
                push(func)
            elseif object(func) then
                for m, f in pairs(func) do
                    if type(m) == "string" and callable(f) then
                        push(f, m)
                    end
                end
            else
                error "Invalid HTTP handler"
            end
        end
    elseif t == "string" then
        local ok, func = pcall(require, func)
        if ok then
            http(push, func, method)
        end
    else
        error "Invalid HTTP handler"
    end
end
return http