local emitter = require('src/cpu/emitter')
local hdlBuilder = require('src/cpu/hdl_builder')


-- array_build from iterator
local function array_build(...)
  local result = {}
  for i,v in ipairs(...) do
    table.insert(result, v)
  end
  return result
end

-- check if `array` contain `value`
local function has_pattern(value, table)
  for i, v in ipairs(table) do
    if string.find(value, v) then
      return true
    end
  end
  return false
end

-- Split a string in to tokens using whitespace as a seperator.
local function tokenize(str)
  local result = {}

  local comment
  str = string.gsub(str, ';', '#', 1)
  local i, j = string.find(str, '#')
  if i and j then
    comment = string.sub(str, j)
    str = string.sub(str, 1, i - 1)
  end

  for v in string.gmatch(str, '%S+') do
    table.insert(result, v)
  end
  if comment then
    table.insert(result, comment)
  end
  return result
end

-- Parse tokens in to an AST we can store and evaluate later.
local function parse(tokens)
  if #tokens == 0 then
    return emitter.make_comment()
  end

  local parseCnt = 1
  local parseExpr

  local peek = function() return tokens[parseCnt] end
  local consume = function()
    local result = peek()
    parseCnt = parseCnt + 1
    return result
  end
  local rewriteLowerAndPeek = function()
    tokens[parseCnt] = string.lower(tokens[parseCnt])
    return peek()
  end

  local parseOp = function()
    local node = { type = 'op', name = consume(), expr = {} }
    if string.sub(node.name, 1, 1) == 'x' then
      node.type = 'ic'
    end
    while (peek()) do
      local expr = parseExpr()
      if expr then
        if expr.type == 'nop' then
          break
        else
          table.insert(node.expr, expr)
        end
      else
        break
      end
    end
    return node
  end
  local parseLabel = function()
    return emitter.make_label(consume())
  end
  local parseConstant = function()
    return emitter.make_value(consume())
  end
  local parseString = function()
    local str = ''
    local n = 0
    while n == 0 or n % 2 ~= 0 do
      local s = consume()
      Assert.check(s ~= nil, 'String is not terminated')
      for i = 1, #s do
        local c = string.sub(s, i, i)
        if c == '\'' then
          n = n + 1
        else
          str = str .. c
        end
      end
      if n % 2 == 1 then
        str = str .. ' '
      end
    end
    return emitter.make_string(str)
  end
  local parseAddress = function(name)
    local token = consume()
    local a, b = string.match(token, name..'(@?)(%d+)')
    return emitter.make_address(b or '', a == '@')
  end
  local parseSignal = function(name)
    local token = consume()
    local m = array_build{ string.match(token, '(-?[%d%.]*)%[([%a%-]+)[=%-]([%a%d%-_:,]+)%]') }
    if m[2] and not (m[2] == 'item' or m[2] == 'fluid' or m[2] == 'virtual-signal') then
      Assert.exception("Signal with type '".. (m[2] or 'nil') .."' is not supported")
    end
    if m[2] == 'virtual-signal' then
      m[2] = 'virtual'
    end
    return emitter.make_signal({type = m[2], name = m[3]}, m[1])
  end
  local parseRegister = function(name, alias)
    local address = parseAddress(alias or name)
    return emitter.make_register(name, address)
  end
  local parseReadOnlyRegister = function(name)
    if string.find(name, 'ipt') then
      return emitter.make_special_register_ro(REG_IP)
    elseif string.find(name, 'clk') then
      return emitter.make_special_register_ro(REG_CLK)
    else
      local w, i = string.match(name, 'cn([rgm])(%d*)')
        if w == 'm' and i ~= nil then
          return emitter.make_special_register_ro(REG_CNM + tonumber(i) - 1)
      elseif w ~= 'm' then
        return emitter.make_special_register_ro(w == 'r' and REG_CNR or w == 'g' and REG_CNG)
      else
        Assert.exception('Unknown register `'..name..'`')
      end
    end
  end
  local parseMemory = function(name, alias)
    local token = consume()
    local a, b, d, e = string.match(token, (alias or name)..'(%d+)([@%[]?)(%d*)(%]?)')

    local index = a
    local addr
    if b == '@' or b == '[' and e == ']' then
      addr = d
    end
    return emitter.make_memory(name, index, addr, b == '@')
  end
  local parseInput = function(name)
    local address = parseAddress(name)
    return emitter.make_wire(name, address)
  end
  local parseOutput = function(name)
    local address
    if peek() == 'out' then
      consume()
      Assert.deprecated('0.2.0', 'You should replace `out` with `out1`')
      address = { addr = nil, pointer = false }
    else
      address = parseAddress(name)
    end
    return emitter.make_wire(name, address)
  end

  parseExpr = function()
    if peek() then
      local fc = string.sub(peek(), 1, 1)
      if fc == '#' then
        return emitter.make_comment()
      elseif fc == ':' then
        return parseLabel()
      elseif string.find(peek(), '(-?[%d%.]*)%[') == 1 then
        return parseSignal()
      elseif string.find(peek(), '[%-]?%d') == 1 then
        return parseConstant()
      elseif fc == '\'' then
        return parseString()
      else
        local token = rewriteLowerAndPeek()

        if string.find(token, 'red') then
          return parseInput('red')
        elseif string.find(token, 'green') then
          return parseInput('green')
        elseif string.find(token, 'out') then
          return parseOutput('out')

        elseif string.find(token, 'mem') then
          return parseMemory('mem')
        elseif string.find(token, 'm%d[@%[]?%d?') == 1 then
          return parseMemory('mem', 'm')

        elseif string.find(token, 'reg') then
          return parseRegister('reg')
        elseif string.find(token, 'r@?%d') == 1 then
          return parseRegister('reg', 'r')
        elseif has_pattern(token, {'ipt', 'cnr', 'cng', 'clk', 'cnm%d'}) then
          return parseReadOnlyRegister(consume())
        else
          return parseOp()
        end
      end
    end
  end
  return parseExpr()
end

local Compiler = {}

local function linepairs(s)
  if s:sub(-1)~="\n" then s=s.."\n" end
  return s:gmatch("(.-)\n")
end

local function compiler_compile(lines)
  local ast = {}
  for i, line in ipairs(lines) do
    local status, result = pcall(parse, tokenize(line))
    --local status, result = true, parse(tokenize(line))
    if not status then
      local error = ''..result
      local start_index = string.find(error, '@') or 0
      error = string.sub(error, start_index+1, -1)
      ast[i] = { type='error', error=error }
    else
      ast[i] = result
    end
  end
  return ast
end

function Compiler.compile(text)
  local program_lines = {}
  for line in linepairs(text) do
    table.insert(program_lines, line)
  end
  return compiler_compile(program_lines)
end

function Compiler.build(state, force)
  local construct = function(k, ast)
    local name, ics, deffer = hdlBuilder.construct(ast, state)
    if name then
      ast.push_ics = { {name=name, index=k} }
    else
      ast.push_ics = nil
    end
    return ics, deffer
  end

  state.d_j = nil

  for k, v in ipairs(state.program_ast) do
    if v.type == 'ic' then
      if force or not hdlBuilder.validate_ics(state.program_ics[k]) then
        hdlBuilder.destroy_ics(state.program_ics[k])

        local status, result, deffer = pcall(construct, k, v)
        --local status, result, deffer = construct(k, v)
        if not status then
          local start_index = string.find(result, '@') or 1
          result = string.sub(result, start_index+1, -1)
          state.program_ast[k] = { type='error', error=result }
        else
          state.program_ast[k].deffer = deffer
          state.program_ics[k] = result
        end
      end
    else
      hdlBuilder.destroy_ics(state.program_ics[k])
      state.program_ast[k].deffer = nil
      state.program_ics[k] = nil
    end
  end
end

function Compiler.verify(state)
  hdlBuilder.verify(state)
end


function Compiler.setup(evaluator_, controller_)
  evaluator_.setup(emitter, controller_)
end
return Compiler
