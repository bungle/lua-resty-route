local upload = require "resty.upload"
local tmpname = os.tmpname
local concat = table.concat
local sub = string.sub
local find = string.find
local open = io.open
local var = ngx.var

local function kv(r, s)
    if s == "formdata" then return end
    local e = find(s, "=", 1, true)
    if e then
        r[sub(s, 2, e - 1)] = sub(s, e + 2, #s - 1)
    else
        r[#r+1] = s
    end
end

local function parse(s)
    if not s then return nil end
    local r = {}
    local i = 1
    local b = find(s, ";", 1, true)
    while b do
        local p = sub(s, i, b - 1)
        kv(r, p)
        i = b + 1
        b = find(s, ";", i, true)
    end
    local p = sub(s, i)
    if p ~= "" then kv(r, p) end
    return r
end

return function(route)
    return function(options)
        options = options or {}
        local ct = var.http_content_type
        if ct == nil then return end
        local post = { n = 0 }
        local files = { n = 0 }
        if sub(ct, 1, 19) == "multipart/form-data" then
            local chunk   = options.chunk_size or 8192
            local form, e = upload:new(chunk)
            if not form then return nil, e end
            local h, p, f, o
            form:set_timeout(options.timeout or 1000)
            while true do
                local t, r, e = form:read()
                if not t then return nil, e end
                if t == "header" then
                    if not h then h = {} end
                    local k, v = r[1], parse(r[2])
                    if v then h[k] = v end
                elseif t == "body" then
                    if h then
                        local d = h["Content-Disposition"]
                        if d then
                            if d.filename then
                                f = {
                                    name = d.name,
                                    type = h["Content-Type"] and h["Content-Type"][1],
                                    tmpname = tmpname()
                                }
                                o, e = open(f.tmpname, "w+")
                                if not o then return nil, e end
                                o:setvbuf("full", chunk)
                            else
                                p = { name = d.name, data = { n = 1 } }
                            end
                        end
                        h = nil
                    end
                    if o then
                        local ok, e = o:write(r)
                        if not ok then return nil, e end
                    elseif p then
                        local n = p.data.n
                        p.data[n] = r
                        p.data.n = n + 1
                    end
                elseif t == "part_end" then
                    if o then
                        f.size = o:seek()
                        o:close()
                        o = nil
                    end
                    local c, d
                    if f then
                        c, d, f = files, f, nil
                    elseif p then
                        c, d, p = post, p, nil
                    end
                    if c then
                        local n = d.name
                        local s = d.data and concat(d.data) or d
                        if n then
                            local z = c[n]
                            if z then
                                if z.n then
                                    z.n = z.n + 1
                                    z[z.n] = s
                                else
                                    z = { z, s }
                                    z.n = 2
                                end
                            else
                                c[n] = s
                            end
                        else
                            c[c.n+1] = s
                            c.n = c.n + 1
                        end
                    end
                elseif t == "eof" then
                    break
                end
            end
            local t, r, e = form:read()
            if not t then return nil, e end
        end
        route.context.post  = post
        route.context.files = files
    end
end