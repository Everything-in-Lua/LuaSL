local function ParseError(msg)
  error("ParseError: " .. msg, 0)
end

local function Parser(tokens)
  local self = {
    tokens = tokens,
    i = 1,
  }

  local function peek()
    return self.tokens[self.i]
  end

  local function advance()
    local tok = self.tokens[self.i]
    self.i = self.i + 1
    return tok
  end

  local function match_kinds(...)
    local kinds = { ... }
    local k = peek().kind
    for i = 1, #kinds do
      if k == kinds[i] then
        return advance()
      end
    end
    return nil
  end

  local function expect(kind, msg)
    local tok = peek()
    if tok.kind ~= kind then
      ParseError(msg .. " at " .. tok.line .. ":" .. tok.col)
    end
    return advance()
  end

  local function peek_ahead(n)
    local j = self.i + n
    if j > #self.tokens then
      return self.tokens[#self.tokens]
    end
    return self.tokens[j]
  end

  local parse_expression, parse_or, parse_and, parse_equality
  local parse_comparison, parse_term, parse_factor, parse_unary
  local parse_postfix, parse_primary

  parse_expression = function()
    return parse_or()
  end

  parse_or = function()
    local expr = parse_and()
    while match_kinds("OR") do
      expr = { tag = "Binary", op = "or", left = expr, right = parse_and() }
    end
    return expr
  end

  parse_and = function()
    local expr = parse_equality()
    while match_kinds("AND") do
      expr = { tag = "Binary", op = "and", left = expr, right = parse_equality() }
    end
    return expr
  end

  parse_equality = function()
    local expr = parse_comparison()
    while true do
      if match_kinds("EQ") then
        expr = { tag = "Binary", op = "==", left = expr, right = parse_comparison() }
      elseif match_kinds("NEQ") then
        expr = { tag = "Binary", op = "!=", left = expr, right = parse_comparison() }
      else
        break
      end
    end
    return expr
  end

  parse_comparison = function()
    local expr = parse_term()
    while true do
      if match_kinds("<") then
        expr = { tag = "Binary", op = "<", left = expr, right = parse_term() }
      elseif match_kinds(">") then
        expr = { tag = "Binary", op = ">", left = expr, right = parse_term() }
      elseif match_kinds("LE") then
        expr = { tag = "Binary", op = "<=", left = expr, right = parse_term() }
      elseif match_kinds("GE") then
        expr = { tag = "Binary", op = ">=", left = expr, right = parse_term() }
      else
        break
      end
    end
    return expr
  end

  parse_term = function()
    local expr = parse_factor()
    while true do
      if match_kinds("+") then
        expr = { tag = "Binary", op = "+", left = expr, right = parse_factor() }
      elseif match_kinds("-") then
        expr = { tag = "Binary", op = "-", left = expr, right = parse_factor() }
      else
        break
      end
    end
    return expr
  end

  parse_factor = function()
    local expr = parse_unary()
    while true do
      if match_kinds("*") then
        expr = { tag = "Binary", op = "*", left = expr, right = parse_unary() }
      elseif match_kinds("/") then
        expr = { tag = "Binary", op = "/", left = expr, right = parse_unary() }
      else
        break
      end
    end
    return expr
  end

  parse_unary = function()
    if match_kinds("-") then
      return { tag = "Unary", op = "-", expr = parse_unary() }
    end
    if match_kinds("!") then
      return { tag = "Unary", op = "!", expr = parse_unary() }
    end
    return parse_postfix()
  end

  parse_postfix = function()
    local expr = parse_primary()
    while match_kinds(".") do
      local name = expect("IDENT", "Expected member name").value
      expr = { tag = "Member", base = expr, name = name }
    end
    return expr
  end

  parse_primary = function()
    local tok = peek()
    if tok.kind == "NUMBER" then
      return { tag = "Number", value = advance().value }
    end
    if tok.kind == "TRUE" then
      advance()
      return { tag = "Bool", value = true }
    end
    if tok.kind == "FALSE" then
      advance()
      return { tag = "Bool", value = false }
    end
    if tok.kind == "IDENT" or tok.kind == "TYPE" then
      local kind = tok.kind
      local name = advance().value
      if match_kinds("(") then
        local args = {}
        if peek().kind ~= ")" then
          table.insert(args, parse_expression())
          while match_kinds(",") do
            table.insert(args, parse_expression())
          end
        end
        expect(")", "Expected ')' after call arguments")
        return { tag = "Call", name = name, args = args }
      end
      if kind == "TYPE" then
        ParseError("Type name used as value: " .. name .. " at " .. tok.line .. ":" .. tok.col)
      end
      return { tag = "Var", name = name }
    end
    if tok.kind == "(" then
      advance()
      local expr = parse_expression()
      expect(")", "Expected ')' after expression")
      return expr
    end
    ParseError("Unexpected token " .. tok.kind .. " at " .. tok.line .. ":" .. tok.col)
  end

  local function parse_type_name(context)
    local tok = peek()
    if tok.kind == "TYPE" or tok.kind == "IDENT" then
      return advance().value
    end
    ParseError("Expected " .. context .. " type at " .. tok.line .. ":" .. tok.col)
  end

  local function parse_param()
    local name = expect("IDENT", "Expected parameter name").value
    expect(":", "Expected ':' after parameter name")
    local type_name = parse_type_name("parameter")
    return { name = name, type_name = type_name }
  end

  local function parse_statement()
    local tok = peek()
    if tok.kind == "LET" or tok.kind == "VAR" then
      local is_var = advance().kind == "VAR"
      local name = expect("IDENT", "Expected variable name").value
      expect(":", "Expected ':' after variable name")
      local type_name = parse_type_name("variable")
      expect("=", "Expected '=' after variable type")
      local value = parse_expression()
      return { tag = "Let", name = name, type_name = type_name, value = value, mutable = is_var }
    end
    if tok.kind == "RETURN" then
      advance()
      local next = peek().kind
      if next == "END" or next == "ELSE" or next == "EOF" then
        return { tag = "Return", value = nil }
      end
      return { tag = "Return", value = parse_expression() }
    end
    if tok.kind == "IDENT" and peek_ahead(1).kind == "=" then
      local name = advance().value
      expect("=", "Expected '=' in assignment")
      return { tag = "Assign", name = name, value = parse_expression() }
    end
    if tok.kind == "IF" then
      advance()
      local cond = parse_expression()
      expect("THEN", "Expected 'then' after if condition")
      local then_body = {}
      while peek().kind ~= "ELSE" and peek().kind ~= "END" and peek().kind ~= "EOF" do
        table.insert(then_body, parse_statement())
      end
      local else_body = nil
      if peek().kind == "ELSE" then
        advance()
        else_body = {}
        while peek().kind ~= "END" and peek().kind ~= "EOF" do
          table.insert(else_body, parse_statement())
        end
      end
      expect("END", "Expected 'end' after if statement")
      return { tag = "If", cond = cond, then_body = then_body, else_body = else_body }
    end
    if tok.kind == "FOR" then
      advance()
      local name = expect("IDENT", "Expected loop variable name").value
      expect(":", "Expected ':' after loop variable")
      local type_name = parse_type_name("loop variable")
      expect("=", "Expected '=' after loop variable type")
      local start_expr = parse_expression()
      expect(",", "Expected ',' after loop start")
      local end_expr = parse_expression()
      local step_expr = nil
      if peek().kind == "," then
        advance()
        step_expr = parse_expression()
      end
      expect("DO", "Expected 'do' after for bounds")
      local body = {}
      while peek().kind ~= "END" and peek().kind ~= "EOF" do
        table.insert(body, parse_statement())
      end
      expect("END", "Expected 'end' after for loop")
      return {
        tag = "For",
        name = name,
        type_name = type_name,
        start_expr = start_expr,
        end_expr = end_expr,
        step_expr = step_expr,
        body = body,
      }
    end
    ParseError("Unexpected token " .. tok.kind .. " at " .. tok.line .. ":" .. tok.col)
  end

  local function parse_global_decl()
    local qualifier = advance().value
    local name = expect("IDENT", "Expected global name").value
    expect(":", "Expected ':' after global name")
    local type_name = parse_type_name("global")
    return { tag = "Global", qualifier = qualifier, name = name, type_name = type_name }
  end

  local function parse_function()
    local annotations = {}
    while peek().kind == "ANNOT" do
      table.insert(annotations, advance().value)
    end
    expect("FUNCTION", "Expected 'function'")
    local name = expect("IDENT", "Expected function name").value
    expect("(", "Expected '(' after function name")
    local params = {}
    if peek().kind ~= ")" then
      table.insert(params, parse_param())
      while match_kinds(",") do
        table.insert(params, parse_param())
      end
    end
    expect(")", "Expected ')' after parameters")
    expect(":", "Expected ':' before return type")
    local ret_type = parse_type_name("return")
    local body = {}
    while peek().kind ~= "END" and peek().kind ~= "EOF" do
      table.insert(body, parse_statement())
    end
    expect("END", "Expected 'end' after function body")
    return { tag = "Function", name = name, params = params, return_type = ret_type, body = body, annotations = annotations }
  end

  local function parse_struct()
    expect("STRUCT", "Expected 'struct'")
    local name = expect("IDENT", "Expected struct name").value
    local fields = {}
    while peek().kind ~= "END" and peek().kind ~= "EOF" do
      local field_name = expect("IDENT", "Expected field name").value
      expect(":", "Expected ':' after field name")
      local field_type = parse_type_name("field")
      table.insert(fields, { name = field_name, type_name = field_type })
    end
    expect("END", "Expected 'end' after struct")
    return { tag = "Struct", name = name, fields = fields }
  end

  local function parse_program()
    local functions = {}
    local structs = {}
    local globals = {}
    local preproc = {}
    while peek().kind ~= "EOF" do
      if peek().kind == "PREPROC" then
        table.insert(preproc, advance().value)
      elseif peek().kind == "STRUCT" then
        table.insert(structs, parse_struct())
      elseif peek().kind == "UNIFORM" or peek().kind == "IN" or peek().kind == "OUT" or peek().kind == "EXTERN" then
        table.insert(globals, parse_global_decl())
      else
        table.insert(functions, parse_function())
      end
    end
    return { tag = "Program", preproc = preproc, globals = globals, structs = structs, functions = functions }
  end

  return {
    parse = parse_program,
  }
end

return {
  Parser = Parser,
}
