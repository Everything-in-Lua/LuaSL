local lexer = require("luasl.lexer")
local parser = require("luasl.parser")
local typecheck = require("luasl.typecheck")
local glsl = require("luasl.glsl")

local function parse(source)
  local lex = lexer.Lexer(source)
  local toks = lex.tokens()
  local p = parser.Parser(toks)
  return p.parse()
end

local function check(program)
  local checker = typecheck.TypeChecker(program)
  checker.check()
end

local function compile(source, opts)
  local program = parse(source)
  check(program)
  local gen = glsl.GLSLGen(program, opts)
  return gen.emit(), program
end

return {
  parse = parse,
  check = check,
  compile = compile,
}
