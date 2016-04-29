local sub = string.sub
local lower = string.lower
return function(location, pattern)
    return lower(sub(location, 1, #pattern)) == lower(pattern) and pattern or nil
end