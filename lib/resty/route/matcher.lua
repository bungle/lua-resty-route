local require = require
local sub = string.sub
local type = type
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
local matcher = {}
function matcher.routable(pattern)
    if type(pattern) ~= "string" then return false end
    local pattern = sub(pattern, 1, 2)
    if selectors[pattern] then
        return true
    end
    pattern = sub(pattern, 1, 1)
    return selectors[pattern] or pattern == "/"
end
function matcher.find(pattern)
    local s = selectors[sub(pattern, 1, 2)]
    if s then return s, sub(pattern, 3)  end
    s = selectors[sub(pattern, 1, 1)]
    if s then return s, sub(pattern, 2) end
    return matchers.prefix, pattern
end
return matcher