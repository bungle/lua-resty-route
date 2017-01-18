local match    = ngx.re.match
local unpack   = table.unpack or unpack
local concat   = table.concat
local find     = string.find
local sub      = string.sub
local huge     = math.huge
local tonumber = tonumber
local unescape = ngx.unescape_uri
return function(location, pattern)
    local i, c, p, j, n = 1, {}, {}, 0, 1
    local s = find(pattern, ":", 1, true)
    while s do
        p[n] = sub(pattern, i, s - 1)
        n = n + 1
        local x = sub(pattern, s, s + 6)
        if x == ":number" then
            p[n] = [[(\d+)]]
            s, j, n = s + 7, j + 1, n + 1
            c[j] = tonumber
        elseif x == ":string" then
            p[n] = [[([^/]+)]]
            s, j, n = s + 7, j + 1, n + 1
            c[j] = unescape
        end
        i = s
        s = find(pattern, ":", s + 1, true)
    end
    if j > 0 then
        p[n] = sub(pattern, i)
        pattern = concat(p)
    end
    local m = match(location, concat{ pattern, "$" }, "ajosu")
    if m then
        if m[1] then
            for i = 1, j do
                m[i] = c[i](m[i])
                if m[i] == huge then return nil end
            end
            return unpack(m)
        end
        return m[0]
    end
    return nil
end
