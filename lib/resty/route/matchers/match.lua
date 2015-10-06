local match = string.match
local concat = table.concat
return function(location, pattern)
    return match(location, concat{ "^", pattern, "$" })
end