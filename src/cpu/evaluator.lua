local Assert = require('src/cpu/assert')
local io = require('src/cpu/io')
local ops = require('src/cpu/opcodes')
local ops_vx = require('src/cpu/opcodes_vx')
local Evaluator = {}


local function update_ics_stack(push_ics)
  for _,v in ipairs(push_ics) do
    local ast = io.get_node_ast(v.name)
    if ast and ast.deffer and ast.deffer.clr then
      io.add_deferred(ast.deffer.clr)
    end
    if string.sub(v.name, 1, 3) == 'mem' then
      io.memory_clear({type='memory', location='mem', index=string.sub(v.name, 4, 4)})
    end
  end
  for _,v in ipairs(push_ics) do
    io.ics_set(v.name, v.index)
  end
end

--- Evaluates an AST.
local function eval(ast, ics)
  local node = function(_)
    if _.type == 'op' then
      if ops[_.name] then
        return ops[_.name](_.expr)
      else
        Assert.exception('Unknown opcode: '.._.name)
      end
    elseif _.type == 'ic' then
      if ops_vx[_.name] then
        local result = ops_vx[_.name](_.expr, ics)
        if _.push_ics then
          update_ics_stack(_.push_ics)
        end
        return result
      else
        Assert.exception('Unknown opcode: '.._.name)
      end
    elseif _.type == 'nop' or _.type == 'label' then
      -- do nothing
    elseif _.type == 'error' and _.error ~= nil then
      Assert.exception(_.error)
    elseif _.type == 'value' or _.type == 'string' then
      return _.str or _.count
    else
      Assert.exception('Unable to parse code '.. serpent.block(_))
    end
  end

  if ast then
    local result = node(ast)
    if type(result) == 'number' then
      Assert.exception('Expected an opcode but instead read an integer.')
    end
    return result
  end
end

function Evaluator.eval(ast, ics, state)
  io.bind(state)

  local status, results = pcall(eval, ast, ics)
  --local status, results = true, eval(ast)
  if not status then
    local start_index = string.find(results, '@') or 1
    results = string.sub(results, start_index+1, -1)
  end
  return status, results
end



function Evaluator.setup(hdlBuilder_, emitter_, controller_)
  io.setup(hdlBuilder_, emitter_, controller_)
  ops.setup(io)
  ops_vx.setup(io)
end
return Evaluator
