local function GLSLGen(program, opts)
  local target = (opts and opts.target) or "glsl"
  local function emit_expr(expr)
    if expr.tag == "Number" then
      return expr.value
    end
    if expr.tag == "Bool" then
      return expr.value and "true" or "false"
    end
    if expr.tag == "Var" then
      return expr.name
    end
    if expr.tag == "Unary" then
      return expr.op .. emit_expr(expr.expr)
    end
    if expr.tag == "Binary" then
      return "(" .. emit_expr(expr.left) .. " " .. expr.op .. " " .. emit_expr(expr.right) .. ")"
    end
    if expr.tag == "Call" then
      local args = {}
      for i = 1, #expr.args do
        args[i] = emit_expr(expr.args[i])
      end
      return expr.name .. "(" .. table.concat(args, ", ") .. ")"
    end
    if expr.tag == "Member" then
      return emit_expr(expr.base) .. "." .. expr.name
    end
    error("Unknown expression", 0)
  end

  local function emit_stmt(stmt, is_mc_main)
    if stmt.tag == "Let" then
      local kw = ""
      if not stmt.mutable and target ~= "minecraft" then
        kw = "const "
      end
      return kw .. stmt.type_name .. " " .. stmt.name .. " = " .. emit_expr(stmt.value) .. ";"
    end
    if stmt.tag == "Assign" then
      return stmt.name .. " = " .. emit_expr(stmt.value) .. ";"
    end
    if stmt.tag == "Return" then
      if stmt.value == nil then
        return "return;"
      end
      if is_mc_main then
        return "fragColor = " .. emit_expr(stmt.value) .. ";"
      end
      return "return " .. emit_expr(stmt.value) .. ";"
    end
    if stmt.tag == "If" then
      local lines = {}
      lines[#lines + 1] = "if (" .. emit_expr(stmt.cond) .. ") {"
      for i = 1, #stmt.then_body do
        lines[#lines + 1] = "    " .. emit_stmt(stmt.then_body[i], is_mc_main)
      end
      if stmt.else_body then
        lines[#lines + 1] = "} else {"
        for i = 1, #stmt.else_body do
          lines[#lines + 1] = "    " .. emit_stmt(stmt.else_body[i], is_mc_main)
        end
      end
      lines[#lines + 1] = "}"
      return table.concat(lines, "\n")
    end
    if stmt.tag == "For" then
      local step = stmt.step_expr and emit_expr(stmt.step_expr) or "1"
      local lines = {}
      lines[#lines + 1] = "for (int " .. stmt.name .. " = " .. emit_expr(stmt.start_expr) .. "; " .. stmt.name .. " <= " .. emit_expr(stmt.end_expr) .. "; " .. stmt.name .. " += " .. step .. ") {"
      for i = 1, #stmt.body do
        lines[#lines + 1] = "    " .. emit_stmt(stmt.body[i], is_mc_main)
      end
      lines[#lines + 1] = "}"
      return table.concat(lines, "\n")
    end
    error("Unknown statement", 0)
  end

  local function emit_struct(st)
    local out = {}
    out[#out + 1] = "struct " .. st.name .. " {"
    for i = 1, #st.fields do
      local f = st.fields[i]
      out[#out + 1] = "    " .. f.type_name .. " " .. f.name .. ";"
    end
    out[#out + 1] = "};"
    return out
  end

  local function emit_function(fn)
    local out = {}
    for i = 1, #fn.annotations do
      out[#out + 1] = "// @" .. fn.annotations[i]
    end
    local params = {}
    for i = 1, #fn.params do
      local p = fn.params[i]
      params[i] = p.type_name .. " " .. p.name
    end
    local is_mc_main = (target == "minecraft" and fn.name == "main")
    local ret_type = is_mc_main and "void" or fn.return_type
    out[#out + 1] = ret_type .. " " .. fn.name .. "(" .. table.concat(params, ", ") .. ") {"
    for i = 1, #fn.body do
      local stmt_lines = emit_stmt(fn.body[i], is_mc_main)
      for line in stmt_lines:gmatch("[^\n]+") do
        out[#out + 1] = "    " .. line
      end
    end
    out[#out + 1] = "}"
    return out
  end

  local function emit()
    local default_version = target == "minecraft" and "#version 330" or "#version 330 core"
    local lines = {}
    local has_version = false
    for i = 1, #program.preproc do
      if program.preproc[i]:match("^#version") then
        if not has_version then
          lines[#lines + 1] = program.preproc[i]
          has_version = true
        end
      end
    end
    if not has_version then
      lines[#lines + 1] = default_version
    end
    lines[#lines + 1] = ""
    for i = 1, #program.preproc do
      if not program.preproc[i]:match("^#version") then
        lines[#lines + 1] = program.preproc[i]
      end
    end
    if #program.preproc > 0 then
      lines[#lines + 1] = ""
    end
    for i = 1, #program.globals do
      local g = program.globals[i]
      if g.qualifier ~= "extern" then
        lines[#lines + 1] = g.qualifier .. " " .. g.type_name .. " " .. g.name .. ";"
      end
    end
    if #program.globals > 0 then
      lines[#lines + 1] = ""
    end
    for i = 1, #program.structs do
      local st_lines = emit_struct(program.structs[i])
      for j = 1, #st_lines do
        lines[#lines + 1] = st_lines[j]
      end
      lines[#lines + 1] = ""
    end
    for i = 1, #program.functions do
      local fn_lines = emit_function(program.functions[i])
      for j = 1, #fn_lines do
        lines[#lines + 1] = fn_lines[j]
      end
      lines[#lines + 1] = ""
    end
    return table.concat(lines, "\n"):gsub("%s*$", "") .. "\n"
  end

  return {
    emit = emit,
  }
end

return {
  GLSLGen = GLSLGen,
}
