local match = ngx.re.match
local unpack = table.unpack or unpack
local concat = table.concat
return function(location, pattern)
    local m = match(location, concat{ pattern, "$" }, "aijosu")
    if m then
        if m[1] then
            return unpack(m)
        end
        return m[0]
    end
    return nil
end