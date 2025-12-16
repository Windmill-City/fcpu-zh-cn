local io
local state
local Emitter ---@type Emitter
local ioRegister = {}

-- Special purpose Registers (read only), see make_special_register_ro
-- {
REG_IP = MC_REGS_RO_FIRST + 0
REG_CNR = MC_REGS_RO_FIRST + 1
REG_CNG = MC_REGS_RO_FIRST + 2
REG_CLK = MC_REGS_RO_FIRST + 3
REG_CNL = MC_REGS_RO_FIRST + 4
REG_CNM = MC_REGS_RO_MSLOT
-- }

-- Registers
---@param index integer
---@return integer
local function register_get_internal(index)
  if index == REG_IP then
    return state.instruction_pointer
  elseif index == REG_CNR then
    if state.cache.wires.red and state.cache.wires.red.signals then
      return #state.cache.wires.red.signals
    else
      return 0
    end
  elseif index == REG_CNG then
    if state.cache.wires.green and state.cache.wires.green.signals then
      return #state.cache.wires.green.signals
    else
      return 0
    end
  elseif index == REG_CLK then
    return state.clock
  elseif index == REG_CNL then
    return io.lognet_content_size()
  elseif REG_CNM <= index then
    local address = Emitter.make_memory_bank('mem', index - REG_CNM + 1)
    return io.memory_size(address) or 0
  else
    Assert.exception(Errors.UnknownRegisterWithIndex(index))
  end
end

---@param index integer
---@return Signal
local function register_getraw(index)
  Assert.check_range(index, MC_REGS_EXT, 'register')
  if state.regs[index] and not state.regs[index].count then
    state.regs[index].count = 0
  end
  return state.regs[index]
end

---@param index integer
---@param signal Signal
local function register_setraw(index, signal)
  Assert.check_range(index, MC_REGS_EXT, 'register')
  Assert.check(math.abs(signal.count or 0) ~= 1 / 0, Errors.DivisionByZero)
  state.regs[index] = signal
end


---@param address OpRef_Address
---@return integer
function ioRegister.addr_deref(address)
  Assert.check(address.addr ~= nil, Errors.InvalidNilAddress)
  if address.pointer then
    Assert.check(address.addr <= MC_REGS_EXT)
    return register_getraw(address.addr).count
  else
    return address.addr
  end
end

---@param index_expr OpRef_Register
---@return OpRef_Constant
function ioRegister.get(index_expr)
  Assert.check(index_expr.type == 'register', Errors.RegisterExpected)
  local addr = ioRegister.addr_deref(index_expr)
  if MC_REGS_EXT < addr then
    local result = table.deep_copy(NULL_SIGNAL)
    result.count = register_get_internal(addr)
    return result
  else
    return table.deep_copy(register_getraw(addr))
  end
end

---@param index_expr OpRef_Register
---@param value OpRef_Constant
function ioRegister.set(index_expr, value)
  Assert.check(index_expr.type == 'register', Errors.RegisterExpected)
  local addr = ioRegister.addr_deref(index_expr)
  local signal = table.deep_copy(value)
  register_setraw(addr, signal)
end

---@param index_expr OpRef_Register
---@param count integer
function ioRegister.set_count(index_expr, count)
  local value = ioRegister.get(index_expr)
  Assert.check(count == count, Errors.DivisionByZero)
  value.count = count --[[@as int32 ]]
  ioRegister.set(index_expr, value)
end

function ioRegister.bind(state_)
  state = state_
end

---@param emitter_ Emitter
function ioRegister.setup(emitter_, io_)
  Emitter = emitter_
  io = io_
end

return ioRegister
