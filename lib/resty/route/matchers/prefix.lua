local sub = string.sub
return function(location, pattern)
    return sub(location, 1, #pattern) == pattern and pattern or nil
end