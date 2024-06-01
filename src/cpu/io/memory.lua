local state
local Emitter
local ioRegister
local ioChannel
local ioMemory = {}


-- Memory
local function memory_setraw(address, addr, signal)
  local control = ioChannel.write_control(address)
  Assert.check(control ~= nil, "Trying to access nil memory channel")
  if addr == nil and signal == nil then
    -- Clear entire memory
    control.enabled = false
    control.parameters = nil
  else
    control.enabled = true
    Assert.check_range(addr, control.signals_count, 'memory')
    if signal and signal.count then
      Assert.check(signal.signal ~= nil, "Signal type should be specified when assigning to a memory cell")
      Assert.check(math.abs(signal.count) ~= 1 / 0, "Division by zero")
      control.set_signal(addr, signal)
    else
      control.set_signal(addr, nil)
    end
  end
end

local function memory_getraw(address, type)
  local ctrl = ioChannel.read_network(address)
  local value = ctrl and ctrl.get_signal(type)
  if value then
    return { signal = type, count = value }
  end
  return NULL_SIGNAL
end

local function memory_map(address)
  Assert.with_memory_bank(address)
  state.memmap[address.channel] = state.memmap[address.channel] or { i2s = {}, s2i = {} }
  local memmap = state.memmap[address.channel]
  return memmap.i2s, memmap.s2i
end

------------------------------------------------------

function ioMemory.address_of(address, type)
  local i2s, s2i = memory_map(address)
  local hash = type.type ..'='.. type.name
  local addr = s2i[hash]
  if not addr then
    addr = #i2s + 1
    s2i[hash] = addr -- always in sync
    i2s[addr] = hash -- always in sync
    ioChannel.GuiCache_Invalidate(address.channel, 2)
  end
  return addr
end

function ioMemory.first_free_index(address)
  local ctrl = ioChannel.write_control(address)
  for _,v in ipairs(ctrl.parameters) do
    if not v.signal.name then
      return v.index
    end
  end
  Assert.exception('Scalar memory block is full already (max '.. ctrl.signals_count ..' items)')
end

function ioMemory.size(address, scalar)
  local ctrl = ioChannel.read_network(address)
  local signals = ctrl and ctrl.signals
  return signals and #signals or 0
end

function ioMemory.get(address)
  Assert.with_memory_bank(address)
  local addr = ioRegister.addr_deref(address)

  local i2s, s2i = memory_map(address)
  local hash = i2s[addr]
  if hash then
    local t, n = string.match(hash, '(%a+)=([%a%d%-_:]+)')
    local type = { type = t, name = n }
    return table.deep_copy(memory_getraw(address, type))
  else
    local ctrl = ioChannel.read_network(address)
    local s = ctrl.signals and ctrl.signals[addr]
    if s then
      local type = s.signal
      hash = type and type.type ..'='.. type.name
      Assert.check(s2i[hash] == nil)
      i2s[addr] = hash
      s2i[hash] = addr
      ioChannel.GuiCache_Invalidate(address.channel, 2)
      return s
    end
  end
  return NULL_SIGNAL
end

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
      local t, n = string.match(oldHash, '(%a+)=([%a%d%-_:]+)')
      oldOutput = memory_getraw(address, { type = t, name = n })
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

  local hash = type and type.type ..'='.. type.name
  if not hash then
    hash = i2s[addr]
    oldValue.count = oldOutput.count
    newValue.signal = oldOutput.signal
  elseif i2s[addr] ~= hash then
    local oldAddr = s2i[hash]
    if oldAddr then
      local constCtrl = ioChannel.write_control(address)
      oldValue = constCtrl and constCtrl.enabled and constCtrl.parameters[oldAddr]

      i2s[oldAddr] = nil -- always in sync
      s2i[hash] = nil -- always in sync
      memory_setraw(address, oldAddr, nil)
    end
  else
    local constCtrl = ioChannel.write_control(address)
    oldValue = constCtrl and constCtrl.enabled and constCtrl.parameters[addr]
    if not oldValue or oldOutput.count ~= oldValue.count then
      oldValue = { count = 0 }
    end
  end

  newValue.count = newValue.count - (oldOutput.count - oldValue.count);

  i2s[addr] = hash -- always in sync
  s2i[hash] = addr -- always in sync
  memory_setraw(address, addr, newValue)

  ioChannel.GuiCache_Invalidate(address.channel, 5)
end

function ioMemory.clear(address)
  if address == nil or address.bank == nil then
    state.memmap = {}

    for i = 1, MC_MEMORY_CHANNELS do
      ioMemory.clear(Emitter.make_memory_bank('mem', i))
    end
  else
    Assert.is_memory_bank(address)
    memory_setraw(address, nil, nil)
    ioChannel.GuiCache_Invalidate(address.channel, 5)

    state.memmap[address.channel] = { i2s = {}, s2i = {} }
  end
end

function ioMemory.bind(state_)
  state = state_
end

function ioMemory.setup(emitter_, ioRegister_, ioChannel_)
  Emitter = emitter_
  ioRegister = ioRegister_
  ioChannel = ioChannel_
end

return ioMemory
