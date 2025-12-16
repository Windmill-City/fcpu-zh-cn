local state
local Stack = {}

-- Stack LIFO
function Stack.push(val)
  local index = #state.reg_stack + 1
  Assert.check(index <= MC_STACK_SIZE, Errors.StackOverflow)
  state.reg_stack[index] = val
end

function Stack.pop()
  local index = #state.reg_stack
  Assert.check(1 <= index, Errors.StackUnderflow)
  return table.remove(state.reg_stack, index)
end

function Stack.get(index)
  local size = #state.reg_stack
  Assert.check(size < 1, Errors.StackUnderflow)
  Assert.check(1 <= index and index <= size, Errors.StackOOB, index, size)
  return state.reg_stack[size + 1 - index]
end

function Stack.size()
  return #state.reg_stack
end

function Stack.clear()
  state.reg_stack = {}
end

function Stack.bind(state_)
  state = state_
end

return Stack
