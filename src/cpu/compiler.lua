local assert = require('src/cpu/assert')
local io = require('src/cpu/io')
local ops = require('src/cpu/opcodes')

assert.bind()
io.bind(assert)
ops.bind(assert, io)


-- require('constants')
-- {
  OP_NOP = {type = 'nop'}
-- }


-- array_build from iterator
local function array_build(...)
  local result = {}
  for i,v in ipairs(...) do
    table.insert(result, v)
  end
  return result
end

-- check if `array` contain `value`
local function has_value(value, table)
  for i, v in ipairs(table) do
      if value == v then
          return true
      end
  end
  return false
end

-- Split a string in to tokens using whitespace as a seperator.
local function split(str)
  local result = {}
  for v in string.gmatch(str, '%S+') do
    table.insert(result, v)
  end
  return result
end

-- Parse tokens in to an AST we can store and evaluate later.
local function parse(tokens)
  if #tokens == 0 then
    return OP_NOP
  end

  local c = 1
  local parseExpr
  local peek = function() return tokens[c] end
  local consume = function()
    local result = peek()
    c = c + 1
    return result
  end
  local parseOp = function()
    local node = { type = 'op', name = consume(), expr = {} }
    while (peek()) do
      local expr = parseExpr()
      if expr then
        table.insert(node.expr, expr)
      else
        break
      end
    end
    return node
  end
  local parseLabel = function()
    return io.make_label(consume())
  end
  local parseConstant = function(fp)
    return io.make_value(consume(), fp)
  end
  local parseAddress = function(name)
    local token = consume()
    if string.find(token, '@%d') then
      local address = string.gsub(token, name..'@(%d+)', '%1')
      return io.make_address(address, true)
    else
      local index = string.gsub(token, name..'(%d+)', '%1')
      return io.make_address(index, false)
    end
  end
  local parseSignal = function(name)
    local token = consume()
    local m = array_build{ string.match(token, '(%d*)%[([%a%-]+)[=%-]([%a%d%-]+)%]') }
    if m[2] == 'virtual-signal' then
      m[2] = 'virtual'
    end
    return io.make_signal({type = m[2], name = m[3]}, m[1])
  end
  local parseRegister = function(name)
    local address = parseAddress(name)
    return io.make_register(name, address)
  end
  local parseReadOnlyRegister = function(name)
    if string.find(name, 'ipt') then
      return io.make_register_ro(REG_IP)
    elseif string.find(name, 'cnr') then
      return io.make_register_ro(REG_CNR)
    elseif string.find(name, 'cng') then
      return io.make_register_ro(REG_CNG)
    elseif string.find(name, 'clk') then
      return io.make_register_ro(REG_CLK)
    else
      assert.exception('Unknown register `'..name..'`')
    end
  end
  local parseMemory = function(name)
    local address = parseAddress(name)
    return io.make_memory(name, address)
  end
  local parseInput = function(name)
    local address = parseAddress(name)
    return io.make_wire(name, address)
  end
  local parseOutput = function(name)
    consume()
    return io.make_wire('out', { addr = 1, pointer = false})
  end

  parseExpr = function()
    if peek() then
      if string.sub(peek(), 1, 1) == '#' then
        return OP_NOP
      elseif string.sub(peek(), 1, 1) == ':' then
        return parseLabel()
      elseif string.find(peek(), '%[') then
        return parseSignal()
      --elseif string.find(peek(), '[%-]?%d+%.%d*') == 1 then
      --  return parseConstant(true)
      elseif string.find(peek(), '[%-]?%d') == 1 then
        return parseConstant()

      elseif string.find(peek(), 'red') then
        return parseInput('red')
      elseif string.find(peek(), 'green') then
        return parseInput('green')
      elseif string.find(peek(), 'out') then
        return parseOutput('out')

      --elseif string.find(peek(), 'mem') then
      --  return parseMemory('mem')

      elseif string.find(peek(), 'reg') then
        return parseRegister('reg')
      elseif has_value(peek(), {'ipt', 'cnr', 'cng', 'clk'}) then
        return parseReadOnlyRegister(consume())
      else
        return parseOp()
      end
    end
  end
  return parseExpr()
end

--- Evaluates an AST.
local function eval(ast)
  local node = function(_)
    if _.type == 'value' then
      return io.value_get(_)
    elseif _.type == 'op' then
      if ops[_.name] then
        return ops[_.name](_.expr)
      else
        assert.exception('Unknown opcode: '.._.name)
      end
    elseif _.type == 'nop' or _.type == 'label' then
      -- do nothing
    elseif _.type == 'error' and _.error ~= nil then
      assert.exception(_.error)
    else
      assert.exception('Unable to parse code '.. serpent.block(_))
    end
  end

  if ast then
    local result = node(ast)
    if type(result) == 'number' then
      assert.exception('Expected an opcode but instead read an integer.')
    end
    return result
  end
end

local compiler = {}

function compiler.compile(lines)
  local ast = {}
  for i, line in ipairs(lines) do
    local status, result = pcall(parse, split(line))
    --local status, result = true, parse(split(line))
    if not status then
      local start_index = string.find(result, '@') or 1
      result = string.sub(result, start_index+1, -1)
      ast[i] = { type='error', error=result }
    else
      ast[i] = result
    end
  end
  return ast
end

function compiler.eval(ast, control, state)
  io.setup(control, state)

  local status, results = pcall(eval, ast)
  --local status, results = true, eval(ast)
  if not status then
    local start_index = string.find(results, '@') or 1
    results = string.sub(results, start_index+1, -1)
  end
  return status, results
end

return compiler
