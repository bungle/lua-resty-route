local getmetatable = getmetatable
local pairs        = pairs
local type         = type
local floor        = math.floor
local max          = math.max
local sub          = string.sub
local matchers = {
    prefix  = require "resty.route.matchers.prefix",
    prefixi = require "resty.route.matchers.prefixi",
    equals  = require "resty.route.matchers.equals",
    equalsi = require "resty.route.matchers.equalsi",
    match   = require "resty.route.matchers.match",
    regex   = require "resty.route.matchers.regex",
    regexi  = require "resty.route.matchers.regexi",
    simple  = require "resty.route.matchers.simple",
    simplei = require "resty.route.matchers.simplei"
}
local selectors = {
    ["*"]  = matchers.prefixi,
    ["="]  = matchers.equals,
    ["=*"] = matchers.equalsi,
    ["#"]  = matchers.match,
    ["~"]  = matchers.regex,
    ["~*"] = matchers.regexi,
    ["@"]  = matchers.simple,
    ["@*"] = matchers.simplei
}
local utils = {}
function utils.array(t)
    if type(t) ~= "table" then return false end
    local m, c = 0, 0
    for k, _ in pairs(t) do
        if type(k) ~= "number" or k < 0 or floor(k) ~= k then return false end
        m = max(m, k)
        c = c + 1
    end
    return c == m
end
function utils.object(t)
    return type(t) == "table" and not(utils.array(t))
end
function utils.callable(func)
    if type(func) == "function" then
        return true
    end
    local mt = getmetatable(func)
    return mt and mt.__call
end
function utils.routable(pattern)
    if type(pattern) ~= "string" then return false end
    local pattern = sub(pattern, 1, 2)
    if selectors[pattern] then
        return true
    end
    pattern = sub(pattern, 1, 1)
    return selectors[pattern] or pattern == "/"
end
function utils.resolve(pattern)
    local s = selectors[sub(pattern, 1, 2)]
    if s then return s, sub(pattern, 3)  end
    s = selectors[sub(pattern, 1, 1)]
    if s then return s, sub(pattern, 2) end
    return matchers.prefix, pattern
end
return utils