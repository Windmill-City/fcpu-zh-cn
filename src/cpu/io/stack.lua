local state
local Stack = {}

-- ICs
function Stack.push(val)
  state.heap[#state.heap+1] = val
end

function Stack.pop()
  Assert.check(#state.heap > 0, "Stack is empty")
  local val = table.remove(state.heap, #state.heap)
  return val
end

function Stack.size()
  return #state.heap
end

function Stack.clear()
  state.heap = {}
end

function Stack.bind(state_)
  state = state_
end

return Stack
