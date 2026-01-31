local sep = package.config:sub(1, 1)
local script = (arg and arg[0]) or ""
local dir = script:match("^(.*" .. sep .. ")")
if dir and dir ~= "" then
  package.path = dir .. "?.lua;" .. dir .. "?/?.lua;" .. package.path
end

local cli = require("luasl.cli")
os.exit(cli.main({ ... }))
