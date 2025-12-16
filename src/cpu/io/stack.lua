local state
local Stack = {}

-- Stack LIFO
function Stack.push(val)
  local index = #state.reg_stack + 1
  state.stack_pointer = MC_STACK_SIZE - index -- emulate x86
  Assert.check(0 <= state.stack_pointer, Errors.StackOverflow)
  state.reg_stack[index] = val
end

function Stack.pop()
  local index = #state.reg_stack
  state.stack_pointer = index + 1
  Assert.check(1 < state.stack_pointer, Errors.StackUnderflow)
  return table.remove(state.reg_stack, index)
end

function Stack.get(index)
  Assert.todo("index from the end")

  local size = #state.reg_stack
  Assert.check(size < 1, Errors.StackUnderflow)
  Assert.check(1 <= index and index <= size, Errors.StackOOB, index, size)
  return state.reg_stack[size + 1 - index]
end

function Stack.size()
  return MC_STACK_SIZE
end

function Stack.get_pointer()
  return state.stack_pointer
end

function Stack.set_pointer(sp)
  if sp == state.stack_pointer then
    return
  end
  if sp < 1 then
    sp = 1
  end
  local size = MC_STACK_SIZE - sp
  if size < 0 then
    size = 0
  end
  -- TODO: optimize
  while size < #state.reg_stack do
    Stack.pop()
  end
  while #state.reg_stack < size do
    Stack.push(table.deep_copy(NULL_SIGNAL))
  end
end

function Stack.clear()
  state.reg_stack = {}
  state.stack_pointer = MC_STACK_SIZE
  state.base_pointer = state.stack_pointer
end

function Stack.bind(state_)
  state = state_
end

return Stack
