local state
local ioRegister
local Stack = {}

-- Stack LIFO

---@param signal Signal
function Stack.push(signal)
  local index = #state.reg_stack + 1
  state.stack_pointer = MC_STACK_SIZE - index -- emulate x86
  Assert.check(0 <= state.stack_pointer, Errors.StackOverflow)
  state.reg_stack[index] = signal
end

---@return Signal
function Stack.pop()
  local index = #state.reg_stack
  state.stack_pointer = index + 1
  Assert.check(1 < state.stack_pointer, Errors.StackUnderflow)
  return table.remove(state.reg_stack, index)
end

local function stack_index(base_offset)
  local base = MC_STACK_SIZE - state.base_pointer
  local index = base + base_offset
  local size = #state.reg_stack
  Assert.check(1 <= index and index <= size, Errors.StackOOB, index, size)
  return index
end

---@param index integer
---@return Signal
local function stack_getraw(index)
  return state.reg_stack[stack_index(index)]
end

---@param index integer
---@param signal Signal
local function stack_setraw(index, signal)
  state.reg_stack[stack_index(index)] = signal
end

---@param index_expr OpRef_Stack
---@return OpRef_Constant
function Stack.get(index_expr)
  Assert.type(index_expr, { 'stack' })
  local addr = ioRegister.addr_deref(index_expr)
  return table.deep_copy(stack_getraw(addr))
end

---@param index_expr OpRef_Stack
---@param value OpRef_Constant
function Stack.set(index_expr, value)
  Assert.type(index_expr, { 'stack' })
  local addr = ioRegister.addr_deref(index_expr)
  local signal = table.deep_copy(value)
  stack_setraw(addr, signal)
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

function Stack.setup(ioRegister_)
  ioRegister = ioRegister_
end

return Stack
