local state
local Emitter
local ioRegister
local ioChannel
local ioMemory = {}


-- Memory
local function memory_getraw(address, addr)
  local signals = ioChannel.signals(address)
  --Assert.check(signals ~= nil, "Trying to retrieve nil memory channel")
  return signals and signals[addr] or NULL_SIGNAL
end

local function memory_setraw(address, addr, signal, corrective)
  local control = ioChannel.write(address, corrective)
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

function ioMemory.get(address)
  Assert.check(address.bank ~= nil, "Memory bank is not specified")
  local addr = ioRegister.addr_deref(address)
  return table.deep_copy(memory_getraw(address, addr))
end

function ioMemory.set(address, signal)
  Assert.check(address.bank ~= nil, "Memory bank is not specified")
  local addr = ioRegister.addr_deref(address)

  local oldOutput = memory_getraw(address, addr)
  if not (oldOutput and oldOutput.signal) and signal.count == 0 then
    ioChannel.GuiCache_InvalidateMemory(address.channel, 5)
    return
  end

  if oldOutput and oldOutput.signal then
    local constCtrl = ioChannel.write(address)
    local oldValue = constCtrl and constCtrl.enabled and constCtrl.parameters[addr] or { count = 0 }

    --
    state.memmap = state.memmap or {}
    state.memmap[address.channel] = state.memmap[address.channel] or { i2s = {}, s2i = {} }
    local memmap = state.memmap[address.channel]
    local i2s, s2i = memmap.i2s, memmap.s2i

    local hash = signal.signal.type ..'='.. signal.signal.name;
    if i2s[addr] ~= hash then
      if s2i[hash] then
        Assert.check(s2i[hash] == addr, 'Memory remap table is broken')
        s2i[hash] = nil
        oldValue.count = 0
      end

      i2s[addr] = hash -- always in sync
      s2i[hash] = addr -- always in sync
    end

    --
    local newValue = table.deep_copy(signal)
    newValue.count = newValue.count - (oldOutput.count - oldValue.count);
    signal = newValue
  end

  memory_setraw(address, addr, signal)
  ioChannel.GuiCache_InvalidateMemory(address.channel, 5)
end

function ioMemory.clear(address)
  if address == nil or address.bank == nil then
    state.memmap = {}

    for i = 1, MC_MEMORY_CHANNELS do
      ioMemory.clear(Emitter.make_memory_bank('mem', i))
    end
  else
    Assert.check(address.addr == nil, "Should be a memory bank")
    memory_setraw(address, nil, nil, true)
    memory_setraw(address, nil, nil, false)
    -- implicitly called inside above ^^^^ line
    -- ioChannel.GuiCache_InvalidateMemory(address.channel, 5)

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
