local assert = require('cpu/assert')
local addr = require('cpu/address')
local ops = require('cpu/opcodes')


-- require('constants')
-- {
  OP_NOP = {type = 'nop'}
-- }


-- Split a string in to tokens using whitespace as a seperator.
local function split(str)
  local result = {}
  for sub in string.gmatch(str, "%S+") do
    table.insert(result, sub)
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
  local parseNum = function()
    return { val = tonumber(consume()), type = 'num' }
  end
  local parseOp = function()
    local node = { val = consume(), type = 'op', expr = {} }
    while(peek()) do
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
    local label = consume()
    return { type = "label", label = label }
  end
  local parseAddress = function(name)
    local token = consume()
    if string.find(token, "@%d") then
      local address = string.gsub(token, name.."@(%d+)", "%1")
      return {val = tonumber(address), pointer = true}
    else
      local index = string.gsub(token, name.."(%d+)", "%1")
      return {val = tonumber(index), pointer = false}
    end
  end
  local parseWire = function(name)
    local address = parseAddress(name)
    return { type = "wire", color = name, val = address.val, pointer = address.pointer}
  end
  local parseRegister = function(name)
    local address = parseAddress(name)
    return { type = "register", location = name, val = address.val, pointer = address.pointer }
  end
  local parseReadOnlyRegister = function(name, index)
    consume()
    return { type = "register", location = "mem", val = tonumber(index) }
  end
  local parseOutput = function(name)
    consume()
    return { type = "register", location = "out" }
  end

  parseExpr = function()
    if peek() then
      if string.sub(peek(), 1, 1) == "#" then
        return OP_NOP
      elseif string.sub(peek(), 1, 1) == ":" then
        return parseLabel()
      elseif string.find(peek(), "%d") == 1 then
        return parseNum()
      elseif string.find(peek(), "red") then
        return parseWire("red")
      elseif string.find(peek(), "green") then
        return parseWire("green")
      elseif string.find(peek(), "mem") then
        return parseRegister("mem")
      elseif string.find(peek(), "out") then
        return parseOutput("out")
      elseif string.find(peek(), "ipt") then
        return parseReadOnlyRegister("ip", REG_IP)
      elseif string.find(peek(), "cnr") then
        return parseReadOnlyRegister("cnr", REG_CNR)
      elseif string.find(peek(), "cng") then
        return parseReadOnlyRegister("cng", REG_CNG)
      elseif string.find(peek(), "clk") then
        return parseReadOnlyRegister("clk", REG_CLK)
      else
        return parseOp()
      end
    end
  end
  return parseExpr()
end

--- Throws an exception, the exception has a control character prepended to that
--- we can substring the message to only display the error message and not the stack-trace
--- to the user.
local function exception(val)
  error("@"..val, 2)
end

--- Evaluates an AST.
local function eval(ast, control, memory, instruction_pointer, clock)
  local wires = {}
  wires.red = control.get_circuit_network(defines.wire_type.red, defines.circuit_connector_id.combinator_input)
  wires.green = control.get_circuit_network(defines.wire_type.green, defines.circuit_connector_id.combinator_input)

  assert.bind(exception)
  addr.bind(assert, control, wires, memory, instruction_pointer, clock)
  ops.bind(assert, addr)

  local node = function(_)
    if _.type == 'num' then
      return addr.num(_)
    elseif _.type == 'op' then
      if ops[_.val] then
        return ops[_.val](_.expr)
      else
        exception("Unknown opcode: ".._.val)
      end
    elseif _.type == 'nop' or _.type == 'label' then
      -- do nothing
    else
      exception("Unable to parse code")
    end
  end

  if ast then
    local result = node(ast)
    if type(result) == "number" then
      exception("Expected an opcode but instead read an integer.")
    end
    return result
  end
end

local compiler = {}

function compiler.compile(lines)
  local ast = {}
  for i, line in ipairs(lines) do
    ast[i] = parse(split(line))
  end
  return ast
end

function compiler.eval(ast, control, state)
  local status, results = pcall(eval, ast, control, state.memory, state.instruction_pointer, state.clock)
  if not status then
    local start_index = string.find(results, "@") or 1
    results = string.sub(results, start_index+1, -1)
  end
  return status, results
end

return compiler