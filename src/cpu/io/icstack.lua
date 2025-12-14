local state
local ICStack = {}

-- ICs
function ICStack.get_node(name)
  local ics = state.program_ics[name] or state.program_ics[state.ics_stack[name]]
  Assert.check(ics, Errors.UnknownChannel, name)
  return ics
end

function ICStack.ics_set(name, index)
  state.ics_stack[name] = index
end

function ICStack.get_node_ast(name)
  local index = state.ics_stack[name]
  local ast = state.program_ast[index]
  return ast
end

function ICStack.ics_each_ast(proc, name)
  if name then
    local index = state.ics_stack[name]
    local ast = state.program_ast[index]
    if ast then
      proc(ast)
    end
  else
    for k in pairs(state.program_ics) do
      if type(k) == 'number' then
        if state.program_ast[k] then
          proc(state.program_ast[k])
        end
      end
    end
  end
end

function ICStack.bind(state_)
  state = state_
end

return ICStack
