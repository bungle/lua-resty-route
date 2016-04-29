local lower = string.lower
return function(location, pattern)
    return lower(location) == lower(pattern) and location or nil
end