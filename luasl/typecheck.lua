local function TypeError(msg)
  error("TypeError: " .. msg, 0)
end

local function TypeChecker(program)
  local self = {
    program = program,
    funcs = {},
    structs = {},
    globals = {},
    current_func = nil,
  }

  local function expect_type(expected, got, msg)
    if expected ~= got then
      TypeError(msg .. ": expected " .. expected .. ", got " .. got)
    end
  end

  local function expect_argc(call, n)
    if #call.args ~= n then
      TypeError(call.name .. " expects " .. n .. " args")
    end
  end

  local check_expr

  local function check_call(expr, scope)
    local struct_def = self.structs[expr.name]
    if struct_def then
      local fields = struct_def.fields
      if #expr.args ~= #fields then
        TypeError(expr.name .. " expects " .. #fields .. " args")
      end
      for i = 1, #fields do
        local got = check_expr(expr.args[i], scope)
        expect_type(fields[i].type_name, got, "Struct arg mismatch for " .. expr.name)
      end
      return expr.name
    end

    if expr.name == "vec2" or expr.name == "vec3" or expr.name == "vec4" then
      local expect = tonumber(expr.name:sub(4, 4))
      local arg_types = {}
      for i = 1, #expr.args do
        arg_types[i] = check_expr(expr.args[i], scope)
      end
      if #arg_types ~= expect then
        TypeError(expr.name .. " expects " .. expect .. " float arguments")
      end
      for i = 1, #arg_types do
        if arg_types[i] ~= "float" then
          TypeError(expr.name .. " expects " .. expect .. " float arguments")
        end
      end
      return expr.name
    end

    if expr.name == "sin" or expr.name == "cos" or expr.name == "tan" or expr.name == "length" or expr.name == "fract" then
      expect_argc(expr, 1)
      local t = check_expr(expr.args[1], scope)
      if t == "float" or t == "vec2" or t == "vec3" or t == "vec4" then
        if expr.name == "length" then
          return "float"
        end
        return t
      end
      TypeError(expr.name .. " expects float or vector")
    end

    if expr.name == "dot" then
      expect_argc(expr, 2)
      local a = check_expr(expr.args[1], scope)
      local b = check_expr(expr.args[2], scope)
      if a == b and (a == "vec2" or a == "vec3" or a == "vec4") then
        return "float"
      end
      TypeError("dot expects two vectors of same size")
    end

    if expr.name == "normalize" then
      expect_argc(expr, 1)
      local t = check_expr(expr.args[1], scope)
      if t == "vec2" or t == "vec3" or t == "vec4" then
        return t
      end
      TypeError("normalize expects a vector")
    end

    if expr.name == "mix" or expr.name == "clamp" or expr.name == "smoothstep" then
      expect_argc(expr, 3)
      local a = check_expr(expr.args[1], scope)
      local b = check_expr(expr.args[2], scope)
      local c = check_expr(expr.args[3], scope)
      if a == b and c == "float" and (a == "float" or a == "vec2" or a == "vec3" or a == "vec4") then
        return a
      end
      TypeError(expr.name .. " expects (T, T, float)")
    end
    if expr.name == "texture" then
      expect_argc(expr, 2)
      local s = check_expr(expr.args[1], scope)
      local uv = check_expr(expr.args[2], scope)
      if s == "sampler2D" and uv == "vec2" then
        return "vec4"
      end
      TypeError("texture expects (sampler2D, vec2)")
    end

    local sig = self.funcs[expr.name]
    if not sig then
      TypeError("Unknown function " .. expr.name)
    end
    if self.current_func == expr.name then
      TypeError("Recursion is not allowed")
    end
    local param_types, ret = sig[1], sig[2]
    if #param_types ~= #expr.args then
      TypeError("Function " .. expr.name .. " expects " .. #param_types .. " args")
    end
    for i = 1, #expr.args do
      local got = check_expr(expr.args[i], scope)
      expect_type(param_types[i], got, "Argument type mismatch for " .. expr.name)
    end
    return ret
  end

  local function is_known_type(t)
    if t == "float" or t == "int" or t == "bool" or t == "vec2" or t == "vec3" or t == "vec4" or t == "mat2" or t == "mat3" or t == "mat4" or t == "sampler2D" or t == "void" then
      return true
    end
    return self.structs[t] ~= nil
  end

  local function is_const_int(expr)
    return expr.tag == "Number" and not expr.value:find(".", 1, true)
  end

  check_expr = function(expr, scope)
    if expr.tag == "Number" then
      if expr.value:find(".", 1, true) then
        return "float"
      end
      return "int"
    end
    if expr.tag == "Bool" then
      return "bool"
    end
    if expr.tag == "Var" then
      local t = scope[expr.name]
      if not t then
        local gt = self.globals[expr.name]
        if gt then
          return gt
        end
        TypeError("Undefined variable " .. expr.name)
      end
      return t
    end
    if expr.tag == "Unary" then
      local t = check_expr(expr.expr, scope)
      if expr.op == "-" and (t == "float" or t == "int") then
        return t
      end
      if expr.op == "!" and t == "bool" then
        return "bool"
      end
      TypeError("Invalid unary op " .. expr.op .. " for " .. t)
    end
    if expr.tag == "Binary" then
      local left = check_expr(expr.left, scope)
      local right = check_expr(expr.right, scope)
      if expr.op == "+" or expr.op == "-" or expr.op == "*" or expr.op == "/" then
        if left == right and (left == "float" or left == "int" or left == "vec2" or left == "vec3" or left == "vec4") then
          return left
        end
        if (left == "vec2" or left == "vec3" or left == "vec4") and (right == "float" or right == "int") then
          return left
        end
        if (right == "vec2" or right == "vec3" or right == "vec4") and (left == "float" or left == "int") then
          return right
        end
        TypeError("Invalid binary op " .. expr.op .. " for " .. left .. " and " .. right)
      end
      if expr.op == "==" or expr.op == "!=" or expr.op == "<" or expr.op == ">" or expr.op == "<=" or expr.op == ">=" then
        if left == right and (left == "float" or left == "int") then
          return "bool"
        end
        TypeError("Invalid comparison " .. expr.op .. " for " .. left .. " and " .. right)
      end
      if expr.op == "and" or expr.op == "or" then
        if left == "bool" and right == "bool" then
          return "bool"
        end
        TypeError("Logical ops require bool")
      end
      TypeError("Unknown binary op " .. expr.op)
    end
    if expr.tag == "Call" then
      return check_call(expr, scope)
    end
    if expr.tag == "Member" then
      local base_t = check_expr(expr.base, scope)
      if base_t == "vec2" or base_t == "vec3" or base_t == "vec4" then
        if expr.name:match("^[xyzwrgba]+$") and #expr.name >= 1 and #expr.name <= 4 then
          if #expr.name == 1 then
            return "float"
          end
          return "vec" .. tostring(#expr.name)
        end
      end
      local struct_def = self.structs[base_t]
      if struct_def then
        for i = 1, #struct_def.fields do
          local f = struct_def.fields[i]
          if f.name == expr.name then
            return f.type_name
          end
        end
      end
      TypeError("Invalid member " .. expr.name .. " on " .. base_t)
    end
    TypeError("Unknown expression")
  end

  local function clone_scope(scope)
    local out = {}
    for k, v in pairs(scope) do
      out[k] = v
    end
    return out
  end

  local function check_stmt(stmt, scope, ret_type)
    if stmt.tag == "Let" then
      if scope[stmt.name] then
        TypeError("Duplicate variable " .. stmt.name)
      end
      if not is_known_type(stmt.type_name) then
        TypeError("Unknown type " .. stmt.type_name .. " for " .. stmt.name)
      end
      local expr_t = check_expr(stmt.value, scope)
      expect_type(stmt.type_name, expr_t, "Type mismatch in " .. stmt.name)
      scope[stmt.name] = stmt.type_name
      return
    end
    if stmt.tag == "Assign" then
      local target_t = scope[stmt.name] or self.globals[stmt.name]
      if not target_t then
        TypeError("Undefined variable " .. stmt.name)
      end
      local expr_t = check_expr(stmt.value, scope)
      expect_type(target_t, expr_t, "Type mismatch in assignment to " .. stmt.name)
      return
    end
    if stmt.tag == "Return" then
      if ret_type == "void" then
        if stmt.value ~= nil then
          TypeError("Return with value in void function")
        end
        return
      end
      if stmt.value == nil then
        TypeError("Return value required")
      end
      local expr_t = check_expr(stmt.value, scope)
      expect_type(ret_type, expr_t, "Return type mismatch")
      return
    end
    if stmt.tag == "If" then
      local cond_t = check_expr(stmt.cond, scope)
      expect_type("bool", cond_t, "If condition must be bool")
      local then_scope = clone_scope(scope)
      for i = 1, #stmt.then_body do
        check_stmt(stmt.then_body[i], then_scope, ret_type)
      end
      if stmt.else_body then
        local else_scope = clone_scope(scope)
        for i = 1, #stmt.else_body do
          check_stmt(stmt.else_body[i], else_scope, ret_type)
        end
      end
      return
    end
    if stmt.tag == "For" then
      if stmt.type_name ~= "int" then
        TypeError("For loop variable must be int")
      end
      if scope[stmt.name] then
        TypeError("Duplicate variable " .. stmt.name)
      end
      if not is_const_int(stmt.start_expr) or not is_const_int(stmt.end_expr) then
        TypeError("For loop bounds must be constant int literals")
      end
      if stmt.step_expr then
        if not is_const_int(stmt.step_expr) then
          TypeError("For loop step must be a constant int literal")
        end
        local step_val = tonumber(stmt.step_expr.value)
        if not step_val or step_val <= 0 then
          TypeError("For loop step must be positive")
        end
      end
      local loop_scope = clone_scope(scope)
      loop_scope[stmt.name] = "int"
      for i = 1, #stmt.body do
        check_stmt(stmt.body[i], loop_scope, ret_type)
      end
      return
    end
    TypeError("Unknown statement")
  end

  local function check_function(fn)
    self.current_func = fn.name
    local scope = {}
    for name, t in pairs(self.globals) do
      scope[name] = t
    end
    for i = 1, #fn.params do
      local p = fn.params[i]
      if scope[p.name] then
        TypeError("Duplicate parameter " .. p.name .. " in " .. fn.name)
      end
      scope[p.name] = p.type_name
    end
    for i = 1, #fn.body do
      check_stmt(fn.body[i], scope, fn.return_type)
    end
    self.current_func = nil
  end

  local function check()
    for i = 1, #self.program.structs do
      local st = self.program.structs[i]
      if self.structs[st.name] then
        TypeError("Duplicate struct " .. st.name)
      end
      local seen = {}
      for j = 1, #st.fields do
        local f = st.fields[j]
        if seen[f.name] then
          TypeError("Duplicate field " .. f.name .. " in struct " .. st.name)
        end
        seen[f.name] = true
      end
      self.structs[st.name] = st
    end
    for i = 1, #self.program.structs do
      local st = self.program.structs[i]
      for j = 1, #st.fields do
        local f = st.fields[j]
        if not is_known_type(f.type_name) then
          TypeError("Unknown type " .. f.type_name .. " in struct " .. st.name)
        end
      end
    end
    for i = 1, #self.program.globals do
      local g = self.program.globals[i]
      if not is_known_type(g.type_name) then
        TypeError("Unknown type " .. g.type_name .. " for global " .. g.name)
      end
      if self.globals[g.name] then
        TypeError("Duplicate global " .. g.name)
      end
      self.globals[g.name] = g.type_name
    end
    for i = 1, #self.program.functions do
      local fn = self.program.functions[i]
      if self.funcs[fn.name] then
        TypeError("Duplicate function " .. fn.name)
      end
      if self.structs[fn.name] then
        TypeError("Function name conflicts with struct " .. fn.name)
      end
      local params = {}
      for j = 1, #fn.params do
        local t = fn.params[j].type_name
        if not is_known_type(t) then
          TypeError("Unknown type " .. t .. " in function " .. fn.name)
        end
        params[j] = t
      end
      if not is_known_type(fn.return_type) then
        TypeError("Unknown return type " .. fn.return_type .. " in function " .. fn.name)
      end
      self.funcs[fn.name] = { params, fn.return_type }
    end
    for i = 1, #self.program.functions do
      check_function(self.program.functions[i])
    end
  end

  return {
    check = check,
  }
end

return {
  TypeChecker = TypeChecker,
}
