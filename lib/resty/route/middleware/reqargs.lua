local reqargs = require "resty.reqargs"
local remove = os.remove
local pairs = pairs

local function cleanup(self)
    local files = self.files
    for i = 1, files.n, 1 do
        local f = files[i]
        remove(f.temp)
        files[i] = nil
    end
    files.n = nil
    for n, f in pairs(files) do
        if f.n then
            for i = 1, f.n, 1 do
                remove(f[n][i].temp)
            end
        else
            remove(f.temp)
        end
    end
end

return function(self)
    return function(options)
        local get, post, files = reqargs(options)
        self.route:after(cleanup)
        self.get   = get
        self.post  = post
        self.files = files
    end
end