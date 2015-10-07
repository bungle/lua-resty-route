local match = ngx.re.match
local unpack = table.unpack or unpack
local concat = table.concat
local find = string.find
local sub = string.sub
local tonumber = tonumber
return function(location, pattern)
    local i, c, p, j = 1, {}, {}, 0
    local s = find(pattern, ":", 1, true)
    while s do
        p[#p+1] = sub(pattern, i, s - 1)
        local x = sub(pattern, s, s + 6)
        if x == ":number" then
            p[#p+1] = [[(\d+)]]
            s, j = s + 7, j + 1
            c[j] = tonumber
        elseif x == ":string" then
            p[#p+1] = [[([^/]+)]]
            s, j = s + 7, j + 1
            c[j] = false
        end
        i = s
        s = find(pattern, ":", s + 1, true)
    end
    if j > 0 then
        p[#p+1] = sub(pattern, i)
        pattern = concat(p)
    end
    print(pattern)
    local m = match(location, concat{ pattern, "$" }, "aijosu")
    if m then
        if m[1] then
            for i = 1, j do
                if c[i] then
                    m[i] = c[i](m[i])
                end
            end
            return unpack(m)
        end
        return m[0]
    end
    return nil
end