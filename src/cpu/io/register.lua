local io
local state
local ioRegister = {}

-- Special purpose Registers (read only), see make_special_register_ro
-- {
REG_IP = MC_REGS_RO_FIRST + 0
REG_CNR = MC_REGS_RO_FIRST + 1
REG_CNG = MC_REGS_RO_FIRST + 2
REG_CLK = MC_REGS_RO_FIRST + 3
REG_CNM = MC_REGS_RO_MSLOT
-- }

-- Registers
local function register_getreadonly(index)
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
  elseif REG_CNM <= index then
    local signals = io.memory_getchannel_signals({ type = 'memory', location = 'mem', index = index - REG_CNM + 1 })
    return signals and #signals or 0
  else
    Assert.exception('Unknown register with internal index ' .. index)
  end
end

local function register_getraw(index)
  Assert.regs_index_range(index, MC_REGS)
  if state.regs[index] and not state.regs[index].count then
    state.regs[index].count = 0
  end
  return state.regs[index]
end

local function register_setraw(index, signal)
  Assert.regs_index_range(index, MC_REGS)
  Assert.check(math.abs(signal.count or 0) ~= 1 / 0, "Division by zero")
  state.regs[index] = signal
end


function ioRegister.addr_deref(_)
  Assert.check(_.addr ~= nil and _.pointer ~= nil, "Invalid address")
  if _.pointer then
    Assert.check(_.addr <= MC_REGS)
    return register_getraw(_.addr).count
  else
    return _.addr
  end
end

function ioRegister.get(index_expr)
  Assert.check(index_expr.type == 'register', "Register expected")
  local addr = ioRegister.addr_deref(index_expr)
  if MC_REGS < addr then
    local result = table.deep_copy(NULL_SIGNAL)
    result.count = register_getreadonly(addr)
    return result
  else
    return table.deep_copy(register_getraw(addr))
  end
end

function ioRegister.set(index_expr, value)
  Assert.check(index_expr.type == 'register', "Register expected")
  local addr = ioRegister.addr_deref(index_expr)
  local signal = table.deep_copy(value)
  register_setraw(addr, signal)
end

function ioRegister.set_count(index_expr, count)
  local value = ioRegister.get(index_expr)
  Assert.check(count == count, "Division by zero")
  value.count = count
  ioRegister.set(index_expr, value)
end

function ioRegister.bind(state_)
  state = state_
end

function ioRegister.setup(io_)
  io = io_
end

return ioRegister
