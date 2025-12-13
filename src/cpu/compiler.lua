local Emitter = require('src/cpu/emitter')


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
    return Emitter.make_comment()
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
    return Emitter.make_label(consume())
  end
  local parseConstant = function()
    return Emitter.make_value(consume())
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
    return Emitter.make_string(str)
  end
  local parseAddress = function(name)
    local token = consume()
    local a, b = string.match(token, name..'(@?)(%d+)')
    return Emitter.make_reference(b or '', a == '@')
  end
  local parseSignal = function()
    local token = consume()
    local pattern_quality = '(-?[%d%.]*)%[([%a%-]+)[=%-]([%a%d%-_:]+),quality=([%a%d%-_]+)%]'
    local pattern_no_qual = '(-?[%d%.]*)%[([%a%-]+)[=%-]([%a%d%-_:,]+)%]'
    local c, t, n, q = string.match(token, pattern_quality)
    if not t then
      c, t, n = string.match(token, pattern_no_qual)
    end
    if t and not (t == 'item' or t == 'fluid' or t == 'virtual-signal' or t == 'recipe' or t == 'quality') then
      Assert.exception("Signal with type '".. (t or 'nil') .."' is not supported")
    end
    if t == 'virtual-signal' then
      t = 'virtual'
    end
    if c == '' then
      return Emitter.make_type({type = t, name = n, quality = q})
    else
      return Emitter.make_signal({type = t, name = n, quality = q}, c)
    end
  end
  local parseRegister = function(name, alias)
    local address = parseAddress(alias or name)
    return Emitter.make_register(name, address)
  end
  local parseReadOnlyRegister = function(name)
    if string.find(name, 'ipt') then
      return Emitter.make_special_register_ro(REG_IP)
    elseif string.find(name, 'clk') then
      return Emitter.make_special_register_ro(REG_CLK)
    else
      local w, i = string.match(name, 'cn([rglm])(%d*)')
      if w == 'm' and i ~= nil then
        return Emitter.make_special_register_ro(REG_CNM + tonumber(i) - 1)
      elseif w == 'r' then
        return Emitter.make_special_register_ro(REG_CNR)
      elseif w == 'g' then
        return Emitter.make_special_register_ro(REG_CNG)
      elseif w == 'l' then
        return Emitter.make_special_register_ro(REG_CNL)
      end
      Assert.exception('Unknown register `'..name..'`')
    end
  end
  local parseMemory = function(name, alias)
    local token = consume()
    local a, b, d, e = string.match(token, (alias or name)..'(%d+)([@%[]?)(%d*)(%]?)')

    local bank = a
    local addr
    if b == '@' or b == '[' and e == ']' then
      addr = d
      local address = Emitter.make_reference(addr, b == '@')
      return Emitter.make_memory(name, bank, address)
    else
      local address = bank and Emitter.make_memory_bank(name, bank) or Emitter.make_abstract('memory')
      return address
    end
  end
  local parseLogNet = function(name, alias)
    local token = consume()
    local b, d, e = string.match(token, (alias or name)..'([@%[]?)(%d*)(%]?)')

    local addr
    if b == '@' or b == '[' and e == ']' then
      addr = d
    end
    return addr and Emitter.make_lognet(addr, b == '@') or Emitter.make_channel('lognet')
  end
  local parseInput = function(name)
    local address = parseAddress(name)
    return Emitter.make_wire(name, address)
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
    return Emitter.make_wire(name, address)
  end

  parseExpr = function()
    if peek() then
      local fc = string.sub(peek(), 1, 1)
      if fc == '#' then
        return Emitter.make_comment()
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

        elseif string.find(token, 'lgn') then
          return parseLogNet('lgn')
        elseif string.find(token, 'logi') then
          return parseLogNet('lgn', 'logi')

        elseif string.find(token, 'reg') then
          return parseRegister('reg')
        elseif string.find(token, 'r@?%d') == 1 then
          return parseRegister('reg', 'r')
        elseif has_pattern(token, {'ipt', 'cnr', 'cng', 'clk', 'cnl', 'cnm%d'}) then
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

function Compiler.build(state, hdlBuilder, force)
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
  local hdlError = false

  for k, v in ipairs(state.program_ast) do
    if v.type == 'ic' then
      if force or not hdlBuilder.validate_ics(state.program_ics[k]) then
        hdlBuilder.destroy_ics(state.program_ics[k])

        local status, result, deffer = pcall(construct, k, v)
        --local status, result, deffer = construct(k, v)
        if not status then
          local start_index = string.find(result, '@') or 0
          result = string.sub(result, start_index+1, -1)
          state.program_ast[k] = { type='error', error=result }
          hdlError = true
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

  return hdlError
end

function Compiler.verify(state)
end


function Compiler.setup(evaluator_, controller_)
  evaluator_.setup(Emitter, controller_)
end
return Compiler
