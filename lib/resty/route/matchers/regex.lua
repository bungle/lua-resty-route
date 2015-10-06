local match = ngx.re.match
local unpack = table.unpack or unpack
local concat = table.concat
return function(location, pattern)
    local c = match(location, concat{ pattern, "$" }, "aijosu")
    if c then
        if c[1] then
            return unpack(c)
        end
        return c[0]
    end
    return nil
end