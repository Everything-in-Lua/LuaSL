local KEYWORDS = {
  ["let"] = true,
  ["var"] = true,
  ["function"] = true,
  ["return"] = true,
  ["struct"] = true,
  ["uniform"] = true,
  ["in"] = true,
  ["out"] = true,
  ["extern"] = true,
  ["if"] = true,
  ["then"] = true,
  ["else"] = true,
  ["for"] = true,
  ["do"] = true,
  ["end"] = true,
  ["and"] = true,
  ["or"] = true,
  ["true"] = true,
  ["false"] = true,
}

local TYPES = {
  ["float"] = true,
  ["int"] = true,
  ["bool"] = true,
  ["vec2"] = true,
  ["vec3"] = true,
  ["vec4"] = true,
  ["mat2"] = true,
  ["mat3"] = true,
  ["mat4"] = true,
  ["sampler2D"] = true,
  ["void"] = true,
}

local function token(kind, value, line, col)
  return { kind = kind, value = value, line = line, col = col }
end

local function Lexer(src)
  local self = {
    src = src,
    i = 1,
    line = 1,
    col = 1,
  }

  local function peek()
    if self.i > #self.src then
      return "\0"
    end
    return self.src:sub(self.i, self.i)
  end

  local function peek_ahead(n)
    local j = self.i + n
    if j > #self.src then
      return "\0"
    end
    return self.src:sub(j, j)
  end

  local function advance()
    local ch = peek()
    if ch == "\0" then
      return ch
    end
    self.i = self.i + 1
    if ch == "\n" then
      self.line = self.line + 1
      self.col = 1
    else
      self.col = self.col + 1
    end
    return ch
  end

  local function match(expected)
    if peek() == expected then
      advance()
      return true
    end
    return false
  end

  local function skip_line_comment()
    while true do
      local ch = peek()
      if ch == "\n" or ch == "\0" then
        break
      end
      advance()
    end
  end

  local function read_ident_or_keyword()
    local line, col = self.line, self.col
    local s = {}
    while true do
      local ch = peek()
      if ch:match("[%w_]") then
        table.insert(s, advance())
      else
        break
      end
    end
    local text = table.concat(s)
    if KEYWORDS[text] then
      return token(text:upper(), text, line, col)
    end
    if TYPES[text] then
      return token("TYPE", text, line, col)
    end
    return token("IDENT", text, line, col)
  end

  local function read_number()
    local line, col = self.line, self.col
    local s = {}
    local has_dot = false
    while true do
      local ch = peek()
      if ch:match("%d") then
        table.insert(s, advance())
      elseif ch == "." and not has_dot then
        has_dot = true
        table.insert(s, advance())
      else
        break
      end
    end
    return token("NUMBER", table.concat(s), line, col)
  end

  local function read_annotation()
    local line, col = self.line, self.col
    advance()
    local s = {}
    while true do
      local ch = peek()
      if ch:match("[%w_]") then
        table.insert(s, advance())
      else
        break
      end
    end
    return token("ANNOT", table.concat(s), line, col)
  end

  local function read_symbol()
    local line, col = self.line, self.col
    local ch = advance()
    if ch == "=" and match("=") then
      return token("EQ", "==", line, col)
    end
    if ch == "!" and match("=") then
      return token("NEQ", "!=", line, col)
    end
    if ch == "<" and match("=") then
      return token("LE", "<=", line, col)
    end
    if ch == ">" and match("=") then
      return token("GE", ">=", line, col)
    end
    return token(ch, ch, line, col)
  end

  local function tokens()
    local out = {}
    while true do
      local ch = peek()
      if ch == "\0" then
        table.insert(out, token("EOF", "", self.line, self.col))
        return out
      end
      if ch == "#" then
        local line, col = self.line, self.col
        local s = {}
        while true do
          local c = peek()
          if c == "\n" or c == "\0" then
            break
          end
          table.insert(s, advance())
        end
        table.insert(out, token("PREPROC", table.concat(s), line, col))
      elseif ch:match("[%s]") then
        advance()
      elseif ch == "-" and peek_ahead(1) == "-" then
        skip_line_comment()
      elseif ch:match("[%a_]") then
        table.insert(out, read_ident_or_keyword())
      elseif ch:match("%d") or (ch == "." and peek_ahead(1):match("%d")) then
        table.insert(out, read_number())
      elseif ch == "@" then
        table.insert(out, read_annotation())
      else
        table.insert(out, read_symbol())
      end
    end
  end

  return {
    tokens = tokens,
  }
end

return {
  Lexer = Lexer,
}
