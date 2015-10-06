local match = ngx.re.match
local unpack = table.unpack or unpack
local concat = table.concat
local find = string.find
local sub = string.sub
local tonumber = tonumber
local tostring = tostring
return function(location, pattern)
    local i, c, p = 1, {}, {}
    local s = find(pattern, ":", 1, true)
    while s do
        p[#p+1] = sub(pattern, i, s - 1)
        local x = sub(pattern, s, s + 6)
        if x == ":number" then
            p[#p+1] = [[(\d+)]]
            c[#c+1] = tonumber
            s = s + 7
        elseif x == ":string" then
            p[#p+1] = [[([^/]+)]]
            c[#c+1] = tostring
            s = s + 7
        end
        i = s
        s = find(pattern, ":", s + 1, true)
    end
    if #c > 0 then
        p[#p+1] = sub(pattern, i)
        pattern = concat(p)
    end
    local m = match(location, concat{ pattern, "$" }, "aijosu")
    if m then
        if m[1] then
            for i, f in ipairs(c) do
                m[i] = f(m[i])
            end
            return unpack(m)
        end
        return m[0]
    end
    return nil
end