local match  = ngx.re.match
local unpack = table.unpack or unpack
return function(location, pattern)
    local m = match(location, pattern, "josu")
    if m then
        if m[1] then
            return unpack(m)
        end
        return m[0]
    end
    return nil
end