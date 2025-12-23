local state
local Emitter ---@type Emitter
local ioRegister
local ioChannel
local ioMemory = {}


-- Memory

---@param address OpRef_MemoryBank
---@param addr integer?
---@param signal Signal?
local function memory_setraw(address, addr, signal)
  local control = ioChannel.write_control(address)
  Assert.check(control ~= nil, Errors.NilChannel)
  if addr == nil and signal == nil then
    -- Clear entire memory
    control.enabled = false
    if control.remove_section(1) then
      control.add_section()
    end
  else
    ---@cast addr -?
    control.enabled = true
    Assert.check_range(addr, get_ctrl_signals_count(control), 'memory')
    if signal and signal.count then
      Assert.check(signal.signal ~= nil, Errors.NeedSignalid)
      Assert.check(math.abs(signal.count) ~= 1 / 0, Errors.DivisionByZero)
      set_ctrl_slot_signal(control, addr, signal)
    else
      set_ctrl_slot_signal(control, addr, nil)
    end
  end
end

---@param address OpRef_Memory
---@param type SignalID
---@return Signal
local function memory_getraw(address, type)
  local network = ioChannel.read_network(address)
  local value = network and network.get_signal(type)
  if value then
    return { signal = type, count = value }
  end
  return NULL_SIGNAL
end

---@param address OpRef_MemoryBank
---@return table<integer, string>, table<string, integer>
local function memory_map(address)
  Assert.with_memory_bank(address)
  state.memmap[address.channel] = state.memmap[address.channel] or { i2s = {}, s2i = {} }
  local memmap = state.memmap[address.channel]
  return memmap.i2s, memmap.s2i
end

------------------------------------------------------

---@param address OpRef_MemoryBank
---@param type SignalID
---@return integer
function ioMemory.address_of(address, type)
  local i2s, s2i = memory_map(address)
  local hash = hash_FromSignalType(type)
  local addr = s2i[hash]
  if not addr then
    addr = #i2s + 1
    s2i[hash] = addr -- always in sync
    i2s[addr] = hash -- always in sync
    ioChannel.GuiCache_Invalidate(address.channel, 2)
  end
  return addr
end

---@param address OpRef_MemoryBank
---@return integer
function ioMemory.first_free_index(address)
  local ctrl = ioChannel.write_control(address)
  local index = ctrl.sections[1].filters_count + 1
  if index <= MC_OUTPUT then
    return index
  end
--  for _,v in ipairs(ctrl.sections[1].filters) do
--    if not v.signal.name then
--      return v.index
--    end
--  end
  Assert.exception(Errors.ScalarMemoryFull(index - 1))
end

---@param address OpRef_MemoryBank
---@return integer
function ioMemory.size(address, scalar)
  local ctrl = ioChannel.read_network(address)
  local signals = ctrl and ctrl.signals
  return signals and #signals or 0
end

---@param address OpRef_Memory
---@return Signal
function ioMemory.get(address)
  Assert.with_memory_bank(address)
  local addr = ioRegister.addr_deref(address)

  local i2s, s2i = memory_map(address)
  local hash = i2s[addr]
  if hash then
    local type = hash_ToSignalType(hash)
    return table.deep_copy(memory_getraw(address, type))
  else
    local ctrl = ioChannel.read_network(address)
    local s = ctrl.signals and ctrl.signals[addr]
    if s then
      hash = hash_FromSignalType(s.signal)
      Assert.check(s2i[hash] == nil)
      i2s[addr] = hash
      s2i[hash] = addr
      ioChannel.GuiCache_Invalidate(address.channel, 2)
      return s
    end
  end
  return NULL_SIGNAL
end

---@param address OpRef_Memory
---@param signal OpRef_Constant
function ioMemory.set(address, signal)
  Assert.type(signal, {'signal'})
  Assert.with_memory_bank(address)
  local addr = ioRegister.addr_deref(address)

  local i2s, s2i = memory_map(address)
  local type = signal.signal

  local oldOutput
  if type then
    oldOutput = memory_getraw(address, type)
  else
    local oldHash = i2s[addr]
    if oldHash then
      oldOutput = memory_getraw(address, hash_ToSignalType(oldHash))
    end
  end

  local hasOutput = oldOutput and oldOutput.signal
  if not hasOutput then
    if signal.count == 0 then
      return
    end
  end

  local oldValue = { count = 0 }
  local newValue = table.deep_copy(signal)

  local hash = hash_FromSignalType(type)
  if not hash then
    hash = i2s[addr]
    oldValue.count = oldOutput.count
    newValue.signal = oldOutput.signal
  elseif i2s[addr] ~= hash then
    local oldAddr = s2i[hash]
    if oldAddr then
      local constCtrl = ioChannel.write_control(address)
      oldValue = constCtrl and constCtrl.enabled and get_ctrl_slot_signal(constCtrl, oldAddr)

      i2s[oldAddr] = nil -- always in sync
      s2i[hash] = nil -- always in sync
      memory_setraw(address, oldAddr, nil)
    end
  else
    local constCtrl = ioChannel.write_control(address)
    oldValue = constCtrl and constCtrl.enabled and get_ctrl_slot_signal(constCtrl, addr)
    if not oldValue or oldOutput.count ~= oldValue.count then
      oldValue = { count = 0 }
    end
  end

  newValue.count = newValue.count - (oldOutput.count - oldValue.count);

  i2s[addr] = hash -- always in sync
  s2i[hash] = addr -- always in sync
  memory_setraw(address, addr, newValue)

  ioChannel.GuiCache_Invalidate(address.channel, 1)
end

---@param address? OpRef_MemoryBank
function ioMemory.clear(address)
  if address == nil or address.bank == nil then
    state.memmap = {}

    for i = 1, MC_MEMORY_CHANNELS do
      ioMemory.clear(Emitter.make_memory_bank('mem', i))
    end
  else
    Assert.is_memory_bank(address)
    memory_setraw(address, nil, nil)
    ioChannel.GuiCache_Invalidate(address.channel, 3)

    state.memmap[address.channel] = { i2s = {}, s2i = {} }
  end
end

function ioMemory.bind(state_)
  state = state_
end

---@param emitter_ Emitter
function ioMemory.setup(emitter_, ioRegister_, ioChannel_)
  Emitter = emitter_
  ioRegister = ioRegister_
  ioChannel = ioChannel_
end

return ioMemory
