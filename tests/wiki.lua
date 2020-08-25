local md = require('src/wiki/md2frt')

local function run_command_line(arg)
    local function read_file(path, descr)
        local file = io.open(path) or error("Could not open " .. descr .. " file: " .. path)
        local contents = file:read("*a") or error("Could not read " .. descr .. " from " .. path)
        file:close()
        return contents
    end

    local function outpath(path)
        local base, name = path:match("^(.+[/\\])(.+%.)[^/\\]*$")
        --return base .. "/" .. name .."md.lua"
        return name .."md.lua"
    end

    (function(path)
        local s = read_file(path, "input")
        local r, mdstate = md.renderString(s)
        s = "return [==[".. r .."]==]"
        local file = io.open(outpath(path), "w") or error("Could not open output file: " .. outpath(path))
        file:write(s)
        file:close()

        --local sections = md.renderSections(mdstate)
    end)(arg[1])
end

if arg then
    run_command_line(arg)
end
