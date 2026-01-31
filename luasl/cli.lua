local compiler = require("luasl.compiler")

local VERSION = "0.1.0"

local function eprintln(msg)
  io.stderr:write(msg .. "\n")
end

local function read_file(path)
  local f, err = io.open(path, "rb")
  if not f then
    return nil, err
  end
  local data = f:read("*a")
  f:close()
  return data
end

local function write_file(path, data)
  local f, err = io.open(path, "wb")
  if not f then
    return nil, err
  end
  f:write(data)
  f:close()
  return true
end

local function path_sep()
  return package.config:sub(1, 1)
end

local function basename(path)
  local sep = path_sep()
  local name = path:gsub(".*" .. sep, "")
  return name
end

local function dirname(path)
  local sep = path_sep()
  local dir = path:match("^(.*)" .. sep)
  if not dir or dir == "" then
    return "."
  end
  return dir
end

local function replace_ext(path, new_ext)
  local name = path:gsub("%.[^%.]+$", "")
  return name .. new_ext
end

local function is_dir_path(path)
  if path:sub(-1) == "/" or path:sub(-1) == "\\" then
    return true
  end
  return false
end

local function ensure_dir(path)
  local sep = path_sep()
  local cmd
  if sep == "\\" then
    cmd = 'mkdir "' .. path .. '"'
  else
    cmd = 'mkdir -p "' .. path .. '"'
  end
  os.execute(cmd)
end

local function expand_glob(arg)
  if not arg:find("[%*%?]") then
    return { arg }
  end
  local sep = path_sep()
  local cmd
  if sep == "\\" then
    cmd = 'cmd /c dir /b ' .. arg
  else
    cmd = 'ls -1 ' .. arg
  end
  local p = io.popen(cmd)
  if not p then
    return { arg }
  end
  local out = {}
  for line in p:lines() do
    if line ~= "" then
      if sep == "\\" and not line:match("^[A-Za-z]:") then
        local dir = dirname(arg)
        if dir ~= "." then
          line = dir .. sep .. line
        end
      end
      table.insert(out, line)
    end
  end
  p:close()
  if #out == 0 then
    return { arg }
  end
  return out
end

local function collect_inputs(args)
  local inputs = {}
  for i = 1, #args do
    local expanded = expand_glob(args[i])
    for j = 1, #expanded do
      table.insert(inputs, expanded[j])
    end
  end
  return inputs
end

local function find_stage(program, stage)
  for i = 1, #program.functions do
    local fn = program.functions[i]
    for j = 1, #fn.annotations do
      if fn.annotations[j] == stage then
        return true
      end
    end
  end
  return false
end

local function usage()
  print([[
luasl build <files...> [-o <out>] [--stage <fragment|vertex>]
luasl check <files...> [--stage <fragment|vertex>]
luasl --version
]])
end

local function parse_args(argv)
  local out = {
    cmd = nil,
    inputs = {},
    out = nil,
    stage = nil,
  }

  local i = 1
  while i <= #argv do
    local arg = argv[i]
    if arg == "--version" then
      out.cmd = "version"
      return out
    elseif arg == "--help" or arg == "-h" then
      out.cmd = "help"
      return out
    elseif arg == "build" or arg == "check" then
      out.cmd = arg
      i = i + 1
    elseif arg == "-o" then
      out.out = argv[i + 1]
      i = i + 2
    elseif arg == "--stage" then
      out.stage = argv[i + 1]
      i = i + 2
    else
      table.insert(out.inputs, arg)
      i = i + 1
    end
  end
  return out
end

local function output_path(input, out, multi)
  local base = basename(replace_ext(input, ".glsl"))
  if not out then
    return dirname(input) .. path_sep() .. base
  end
  if multi or is_dir_path(out) then
    return out:gsub("[/\\]$", "") .. path_sep() .. base
  end
  return out
end

local function check_stage_or_error(program, stage, input)
  if not stage then
    return true
  end
  if stage ~= "fragment" and stage ~= "vertex" then
    return nil, "Invalid --stage value: " .. stage
  end
  if not find_stage(program, stage) then
    return nil, "No @" .. stage .. " entry point in " .. input
  end
  return true
end

local function cmd_build(opts)
  if #opts.inputs == 0 then
    usage()
    return 1
  end
  local inputs = collect_inputs(opts.inputs)
  if #inputs == 0 then
    eprintln("No input files")
    return 1
  end
  local multi = #inputs > 1
  for i = 1, #inputs do
    local input = inputs[i]
    local src, err = read_file(input)
    if not src then
      eprintln("Read failed: " .. input .. " (" .. err .. ")")
      return 1
    end
    local ok, glsl_or_err, program = pcall(function()
      local glsl, prog = compiler.compile(src)
      return glsl, prog
    end)
    if not ok then
      eprintln(glsl_or_err)
      return 1
    end
    local glsl = glsl_or_err
    local stage_ok, stage_err = check_stage_or_error(program, opts.stage, input)
    if not stage_ok then
      eprintln(stage_err)
      return 1
    end
    local out_path = output_path(input, opts.out, multi)
    local out_dir = dirname(out_path)
    if out_dir ~= "." then
      ensure_dir(out_dir)
    end
    local wrote, werr = write_file(out_path, glsl)
    if not wrote then
      eprintln("Write failed: " .. out_path .. " (" .. werr .. ")")
      return 1
    end
  end
  return 0
end

local function cmd_check(opts)
  if #opts.inputs == 0 then
    usage()
    return 1
  end
  local inputs = collect_inputs(opts.inputs)
  if #inputs == 0 then
    eprintln("No input files")
    return 1
  end
  for i = 1, #inputs do
    local input = inputs[i]
    local src, err = read_file(input)
    if not src then
      eprintln("Read failed: " .. input .. " (" .. err .. ")")
      return 1
    end
    local ok, program_or_err = pcall(function()
      local prog = compiler.parse(src)
      compiler.check(prog)
      return prog
    end)
    if not ok then
      eprintln(program_or_err)
      return 1
    end
    local stage_ok, stage_err = check_stage_or_error(program_or_err, opts.stage, input)
    if not stage_ok then
      eprintln(stage_err)
      return 1
    end
  end
  return 0
end

local function main(argv)
  local opts = parse_args(argv)
  if not opts.cmd then
    usage()
    return 1
  end
  if opts.cmd == "version" then
    print("luasl " .. VERSION)
    return 0
  end
  if opts.cmd == "help" then
    usage()
    return 0
  end
  if opts.cmd == "build" then
    return cmd_build(opts)
  end
  if opts.cmd == "check" then
    return cmd_check(opts)
  end
  usage()
  return 1
end

return {
  main = main,
}
