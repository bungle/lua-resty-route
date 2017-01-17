local getmetatable = getmetatable
local pairs        = pairs
local type         = type
local floor        = math.floor
local max          = math.max
local function array(t)
    if type(t) ~= "table" then return false end
    local m, c = 0, 0
    for k, _ in pairs(t) do
        if type(k) ~= "number" or k < 0 or floor(k) ~= k then return false end
        m = max(m, k)
        c = c + 1
    end
    return c == m
end
local function object(t)
    return type(t) == "table" and not(array(t))
end
local function callable(func)
    if type(func) == "function" then
        return true
    end
    local mt = getmetatable(func)
    return mt and mt.__call
end
return {
    array    = array,
    object   = object,
    callable = callable
}