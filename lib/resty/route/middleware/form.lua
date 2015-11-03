local upload = require "resty.upload"
local tmpname = os.tmpname
local concat = table.concat
local sub = string.sub
local find = string.find
local open = io.open
local var = ngx.var

local function parse(s)
    if not s then return nil end
    local r = {}
    local i = 1
    local b = find(s, ";", 1, true)
    while b do
        local p = sub(s, i, b - 1)
        local e = find(p, "=", 1, true)
        if e then
            r[sub(p, 2, e - 1)] = sub(p, e + 2, #p - 1)
        else
            r[#r+1] = p
        end
        i = b + 1
        b = find(s, ";", i, true)
    end
    local p = sub(s, i)
    if p ~= "" then
        local e = find(p, "=", 1, true)
        if e then
            r[sub(p, 2, e - 1)] = sub(p, e + 2, #p - 1)
        else
            r[#r+1] = p
        end
    end
    return r
end

return function(route)
    return function(options)
        options = options or {}
        local ct = var.http_content_type
        if ct == nil then return end
        local post = {}
        local files = {}
        if sub(ct, 1, 20) == "multipart/form-data;" then
            local chunk   = options.chunk_size or 8192
            local form = upload:new(chunk)
            local n, f, h, p
            form:set_timeout(options.timeout or 1000)
            while true do
                local t, r, e = form:read()
                if not t then
                    return route:error(e)
                end
                if t == "header" then
                    if not h then h = {} end
                    local k, v = r[1], parse(r[2])
                    if v then
                        h[k] = v
                    end
                elseif t == "body" then
                    if h then
                        local d = h["Content-Disposition"]
                        if d then
                            n = d.name
                            local file = d.filename
                            if file then
                                if file ~= "" then
                                    local type = h["Content-Type"]
                                    local data = {
                                        name = file,
                                        tmpname = tmpname(),
                                        type = type and type[1]
                                    }
                                    if n then
                                        local fls = files[n]
                                        if fls then
                                            if fls.n then
                                                fls.n = fls.n + 1
                                                fls[fls.n] = data
                                            else
                                                fls = { fls, data }
                                                fls.n = 2
                                            end
                                        else
                                            files[n] = data
                                        end
                                    else
                                        files[#files+1] = data
                                    end
                                    f, e = open(data.tmpname, "w+")
                                    if f then
                                        f:setvbuf("full", chunk)
                                    else
                                        return route:error(e)
                                    end
                                end
                            else
                                p = {}
                            end
                        end
                        h = nil
                    end
                    if f then
                        f, e = f:write(r)
                        if not f then
                            return route:error(e)
                        end
                    elseif p then
                        p[#p+1] = r
                    end
                elseif t == "part_end" then
                    if f then
                        f:flush()
                        f:close()
                        f = nil
                    elseif p then
                        local data = concat(p)
                        if n then
                            local pst = post[n]
                            if pst then
                                if pst.n then
                                    pst.n = pst.n + 1
                                    pst[pst.n] = data
                                else
                                    pst = {
                                        pst,
                                        data
                                    }
                                    pst.n = 2
                                end
                            else
                                post[n] = data
                            end
                        else
                            post[#post+1] = data
                        end
                        p = nil
                    end
                elseif t == "eof" then
                    break
                end
            end
            local t, r, e = form:read()
            if not t then
                return route:error(e)
            end
        end
        route.context.post  = post
        route.context.files = files
    end
end