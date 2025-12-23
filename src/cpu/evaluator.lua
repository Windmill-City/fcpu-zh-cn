local io = require('src/cpu/io_facade')
local ops = require('src/cpu/opcodes')
local ops_vx = require('src/cpu/opcodes_vx')
local Emitter ---@type Emitter
local Evaluator = {}

State = require('src/cpu/io/state')
State.onBind(io.bind)


local function update_ics_stack(push_ics)
  for _,v in ipairs(push_ics) do
    local ast = io.get_node_ast(v.name)
    if ast and ast.defer and ast.defer.clr then
      io.add_deferred(ast.defer.clr)
    end
    if string.sub(v.name, 1, 3) == 'mem' then
      local bank = string.sub(v.name, 4, -1)
      local address = Emitter.make_memory_bank('mem', bank)
      io.memory_clear(address)
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
        Assert.exception(Errors.UnknownOpcode(_.name))
      end
    elseif _.type == 'ic' then
      if ops_vx[_.name] then
        local result = ops_vx[_.name](_.expr, ics)
        if _.push_ics then
          update_ics_stack(_.push_ics)
        end
        return result
      else
        Assert.exception(Errors.UnknownOpcode(_.name))
      end
    elseif _.type == 'nop' or _.type == 'label' then
      -- do nothing
    elseif _.type == 'error' and _.error ~= nil then
      Assert.exception(_.error)
    elseif _.type == 'value' or _.type == 'string' then
      return _.str or _.count
    else
      Assert.exception(Errors.UnableToParse(serpent.block(_)))
    end
  end

  if ast then
    local result = node(ast)
    if type(result) == 'number' then
      Assert.exception(Errors.ExpectedOpcodeButRead(type(result)))
    end
    return result
  end
end

function eval_debug(ast, ics)
  if MC_DEBUG and false then
    return true, eval(ast, ics) -- forces scenario crash on any exception
  end
  return pcall(eval, ast, ics)
end

function Evaluator.eval(ast, ics, state)
  State.bind(state)

  local status, results = eval_debug(ast, ics)
  return status, results
end



---@param emitter_ Emitter
function Evaluator.setup(emitter_, controller_)
  Emitter = emitter_
  io.setup(emitter_, controller_)
  ops.setup(io)
  ops_vx.setup(io)
end
return Evaluator
