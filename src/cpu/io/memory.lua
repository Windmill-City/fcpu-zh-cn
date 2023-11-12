local state
local Emitter
local ioRegister
local ioChannel
local ioMemory = {}


-- Memory
local function memory_setraw(address, addr, signal)
  local control = ioChannel.write(address)
  Assert.check(control ~= nil, "Trying to access nil memory channel")
  if addr == nil and signal == nil then
    -- Clear entire memory
    control.enabled = false
    control.parameters = nil
  else
    control.enabled = true
    Assert.check(1 <= addr and addr <= MC_OUTPUT, "Memory cell index is out of range")
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
  local ctrl = ioChannel.read(address)
  local value = ctrl and ctrl.get_signal(type)
  if value then
    return { signal = type, count = value }
  end
  return NULL_SIGNAL
end

local function memory_map(address)
  Assert.with_memory_bank(address)
  --state.memmap = state.memmap or {}
  --state.memmap[address.channel] = state.memmap[address.channel] or { i2s = {}, s2i = {} }
  local memmap = state.memmap[address.channel]
  return memmap.i2s, memmap.s2i
end

------------------------------------------------------

function ioMemory.address_of(address, type)
  local i2s, s2i = memory_map(address)
  local hash = type.type ..'='.. type.name
  local addr = s2i[hash]
  if not addr then
    addr = #s2i
    s2i[hash] = addr -- always in sync
    i2s[addr] = hash -- always in sync
  end
  return addr
end

function ioMemory.size(address)
  local ctrl = ioChannel.read(address)
  local signals = ctrl and ctrl.signals
  return signals and #signals or 0
end

function ioMemory.get(address)
  Assert.with_memory_bank(address)
  local addr = ioRegister.addr_deref(address)

  local i2s, s2i = memory_map(address)
  local hash = i2s[addr]
  if hash then
    local t, n = string.match(hash, '(%a+)=([%a%-]+)')
    local type = { type = t, name = n }
    return table.deep_copy(memory_getraw(address, type))
  end
  return NULL_SIGNAL
end

function ioMemory.set(address, signal)
  Assert.with_memory_bank(address)
  local addr = ioRegister.addr_deref(address)

  local i2s, s2i = memory_map(address)
  local type = signal.signal
  local hash = type.type ..'='.. type.name

  local oldOutput
  if type then
    oldOutput = memory_getraw(address, type)
  else
    local oldHash = i2s[addr]
    if oldHash then
      local t, n = string.match(oldHash, '(%a+)=([%a%-]+)')
      oldOutput = memory_getraw(address, { type = t, name = n })
    end
  end
  local hasOutput = oldOutput and oldOutput.signal

  if hasOutput then
    local oldValue = { count = 0 }

    if i2s[addr] ~= hash then
      local oldAddr = s2i[hash]
      if oldAddr then
        local constCtrl = ioChannel.write(address)
        oldValue = constCtrl and constCtrl.enabled and constCtrl.parameters[oldAddr]

        i2s[oldAddr] = nil -- always in sync
        s2i[hash] = nil -- always in sync
        memory_setraw(address, oldAddr, nil)
      end
    end

    local newValue = table.deep_copy(signal)
    newValue.count = newValue.count - (oldOutput.count - oldValue.count);
    signal = newValue
  else
    if signal.count == 0 then
      return
    end
  end

  i2s[addr] = hash -- always in sync
  s2i[hash] = addr -- always in sync
  memory_setraw(address, addr, signal)

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
