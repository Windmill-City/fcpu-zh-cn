local assert = require('src/cpu/assert')
local io = require('src/cpu/io')
local ops = require('src/cpu/opcodes')
local ops_vx = require('src/cpu/opcodes_vx')
local hdlBuilder = require('src/cpu/hdl_builder')


-- require('constants')
-- {
  OP_COMMENT = {type = 'nop', name = 'comment'}
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
local function has_pattern(value, table)
  for i, v in ipairs(table) do
    if string.find(value, v) then
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
    return OP_COMMENT
  end

  local parseCnt = 1
  local parseExpr

  local peek = function() return tokens[parseCnt] end
  local consume = function()
    local result = peek()
    parseCnt = parseCnt + 1
    return result
  end
  local rewriteLower = function()
    tokens[parseCnt] = string.lower(tokens[parseCnt])
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
    return io.make_label(consume())
  end
  local parseConstant = function(fp)
    return io.make_value(consume(), fp)
  end
  local parseAddress = function(name)
    local token = consume()
    local a, b = string.match(token, name..'(@?)(%d+)')
    return io.make_address(b or '', a == '@')
  end
  local parseSignal = function(name)
    local token = consume()
    local m = array_build{ string.match(token, '(-?[%d%.]*)%[([%a%-]+)[=%-]([%a%d%-_:,]+)%]') }
    if m[2] and not (m[2] == 'item' or m[2] == 'fluid' or m[2] == 'virtual-signal') then
      assert.exception("Signal with type '".. (m[2] or 'nil') .."' is not supported")
    end
    if m[2] == 'virtual-signal' then
      m[2] = 'virtual'
    end
    return io.make_signal({type = m[2], name = m[3]}, m[1])
  end
  local parseRegister = function(name, alias)
    local address = parseAddress(alias or name)
    return io.make_register(name, address)
  end
  local parseReadOnlyRegister = function(name)
    if string.find(name, 'ipt') then
      return io.make_register_ro(REG_IP)
    elseif string.find(name, 'clk') then
      return io.make_register_ro(REG_CLK)
    else
      local w, i = string.match(name, 'cn([rgm])(%d*)')
      if w == 'm' and i ~= nil then
        return io.make_register_ro(REG_CNM + tonumber(i) - 1)
      elseif w ~= 'm' then
        return io.make_register_ro(w == 'r' and REG_CNR or w == 'g' and REG_CNG)
      else
        assert.exception('Unknown register `'..name..'`')
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

    if b == '@' then
      return io.make_memory(name, index, addr, true)
    else
      return io.make_memory(name, index, addr, false)
    end
  end
  local parseInput = function(name)
    local address = parseAddress(name)
    return io.make_wire(name, address)
  end
  local parseOutput = function(name)
    local address
    if peek() == 'out' then
      consume()
      assert.deprecated('0.2.0', 'You should replace `out` with `out1`')
      address = { addr = nil, pointer = false }
    else
      address = parseAddress(name)
    end
    return io.make_wire(name, address)
  end

  parseExpr = function()
    if peek() then
      local fc = string.sub(peek(), 1, 1)
      if fc == '#' or fc == ';' then
        return OP_COMMENT
      elseif fc == ':' then
        return parseLabel()
      elseif string.find(peek(), '(-?[%d%.]*)%[') == 1 then
        return parseSignal()
      elseif string.find(peek(), '[%-]?%d') == 1 then
        return parseConstant()
      else
        rewriteLower()

        if string.find(peek(), 'red') then
          return parseInput('red')
        elseif string.find(peek(), 'green') then
          return parseInput('green')
        elseif string.find(peek(), 'out') then
          return parseOutput('out')

        elseif string.find(peek(), 'mem') then
          return parseMemory('mem')
        elseif string.find(peek(), 'm%d[@%[]?%d') == 1 then
          return parseMemory('mem', 'm')

        elseif string.find(peek(), 'reg') then
          return parseRegister('reg')
        elseif string.find(peek(), 'r@?%d') == 1 then
          return parseRegister('reg', 'r')
        elseif has_pattern(peek(), {'ipt', 'cnr', 'cng', 'clk', 'cnm%d'}) then
          return parseReadOnlyRegister(consume())
        else
          return parseOp()
        end
      end
    end
  end
  return parseExpr()
end

local function update_ics_stack(subsystem, push_ics)
  if push_ics then
    for _,v in ipairs(push_ics) do
      subsystem.set_ics(v.name, v.index)
    end
  end
end

--- Evaluates an AST.
local function eval(ast, ics)
  local node = function(_)
    if _.type == 'value' then
      return io.value_get(_)
    elseif _.type == 'op' then
      if ops[_.name] then
        return ops[_.name](_.expr)
      else
        assert.exception('Unknown opcode: '.._.name)
      end
    elseif _.type == 'ic' then
      if ops_vx[_.name] then
        local result = ops_vx[_.name](_.expr, ics)
        if _.push_ics then
          for k,v in ipairs(_.push_ics) do
            local node = io.get_node(v.name)
            if node and node.fix then
              local control = node.fix.get_control_behavior()
              control.enabled = true
            end
          end
        end
        update_ics_stack(io, _.push_ics)
        return result
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

function compiler.build(state, force)
  local construct = function(k, ast)
    local name, ics, deffer = hdlBuilder.construct(ast, state)
    if name then
      ast.push_ics = { {name=name, index=k} }
      update_ics_stack(hdlBuilder, ast.push_ics)
    end
    return ics, deffer
  end

  state.d_j = nil

  for k, v in ipairs(state.program_ast) do
    if v.type == 'ic' then
      if force or not hdlBuilder.validate_ics(state.program_ics[k]) then
        hdlBuilder.destroy_ics(state.program_ics[k])

        local status, result, deffer = pcall(construct, k, v)
        --local status, result, deffer = true, construct(k, v)
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

function compiler.verify(state)
  hdlBuilder.verify(state)
end

function compiler.eval(ast, ics, state)
  local control = state.entity.get_control_behavior()
  io.setup(state, control)

  local status, results = pcall(eval, ast, ics)
  --local status, results = true, eval(ast)
  if not status then
    local start_index = string.find(results, '@') or 1
    results = string.sub(results, start_index+1, -1)
  end
  return status, results
end


function compiler.bind()
  assert.bind()
  io.bind(assert, hdlBuilder)
  ops.bind(assert, io)
  ops_vx.bind(assert, io, hdlBuilder)
end
return compiler
