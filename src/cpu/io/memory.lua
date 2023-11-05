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
  local was = memory_getraw(address, addr)
  if was and was.signal then
    was = table.deep_copy(was)
    was.count = -was.count;
    memory_setraw(address, addr, was, true)
  end
  if signal.count ~= 0 then
    memory_setraw(address, addr, signal)
  end
  ioChannel.GuiCache_InvalidateMemory(address.channel, 5)
end

function ioMemory.clear(address)
  if address == nil or address.bank == nil then
    for i = 1, MC_MEMORY_CHANNELS do
      ioMemory.clear(Emitter.make_memory_bank('mem', i))
    end
  else
    Assert.check(address.addr == nil, "Should be a memory bank")
    memory_setraw(address, nil, nil, true)
    memory_setraw(address, nil, nil, false)
    -- implicitly called inside above ^^^^ line
    -- ioChannel.GuiCache_InvalidateMemory(address.channel, 5)
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
