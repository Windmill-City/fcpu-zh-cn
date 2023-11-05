local state
local output_control
local ICStack
local ioRegister
local ioMemory = {}


-- Memory
function ioMemory.getchannel_read(_)
  if _.type == 'memory' then
    local ics = ICStack.get_node(state, _.location .. _.index)
    if ics and ics.out and ics.out.valid then
      local control = ics.out.get_control_behavior()
      local network = control.get_circuit_network(ics.color_out or defines.wire_type.red,
        defines.circuit_connector_id.combinator_output)
      return network or control
    else
      Assert.exception("Memory channel does not exists")
    end
  elseif _.type == 'wire' then
    if _.color == 'out' then
      return output_control.get_circuit_network(defines.wire_type.red, defines.circuit_connector_id.constant_combinator)
    end
    if not state.cache.wires[_.color] then
      Assert.exception("Tried to access " .. _.color .. " wire when it is not connected")
    end
    return state.cache.wires[_.color]
  else
    Assert.todo()
  end
end

function ioMemory.getchannel_write(_, corrective)
  if _.type == 'memory' then
    local ics = ICStack.get_node(state, _.location .. _.index)
    if ics then
      if corrective then
        if ics.value2 and ics.value2.valid then
          return ics.value2.get_control_behavior()
        end
      else
        if ics.value and ics.value.valid then
          ioMemory.GuiCache_InvalidateMemory(_.location .. _.index, 5)
          return ics.value.get_control_behavior()
        end
      end
    end
    Assert.exception("Memory channel does not support writing")
  elseif _.type == 'wire' then
    if _.color == 'out' then
      return output_control
    end
    Assert.exception("Could not write to " .. _.color .. " input wire")
  else
    Assert.todo()
  end
end

function ioMemory.getchannel_signals(_)
  -- DEPRECATED
  if _.type == 'memory' then
    local ics = ICStack.get_node(state, _.location .. _.index)
    if ics and ics.out and ics.out.valid then
      local control = ics.out.get_control_behavior()
      local output = control.get_circuit_network(ics.color_out or defines.wire_type.red,
        defines.circuit_connector_id.combinator_output)
      return output and output.signals or control.signals_last_tick or {}
    else
      Assert.exception("Memory channel does not exists")
    end
  elseif _.type == 'wire' then
    if _.color == 'out' then
      return output_control.parameters
    end
    if not state.cache.wires[_.color] then
      Assert.exception("Tried to access " .. _.color .. " wire when it is not connected")
    end
    return state.cache.wires[_.color].signals or {}
  else
    Assert.todo()
  end
end

local function memory_getraw(channel, addr)
  local signals = ioMemory.getchannel_signals(channel)
  --Assert.check(signals ~= nil, "Trying to retrieve nil memory channel")
  return signals and signals[addr] or NULL_SIGNAL
end

local function memory_setraw(channel, addr, signal, corrective)
  local control = ioMemory.getchannel_write(channel, corrective)
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
  Assert.check(address.index ~= nil, "Should be addressable memory cell")
  local addr = ioRegister.addr_deref(address)
  return table.deep_copy(memory_getraw(address, addr))
end

function ioMemory.set(address, signal)
  Assert.check(address.index ~= nil, "Should be addressable memory cell")
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
  ioMemory.GuiCache_InvalidateMemory(address.location .. address.index, 5)
end

function ioMemory.clear(address)
  if address == nil or address.index == nil then
    for i = 1, MC_MEMORY_CHANNELS do
      ioMemory.clear { type = 'memory', location = 'mem', index = i }
    end
  else
    Assert.check(address.addr == nil, "Should be a memory channel")
    memory_setraw(address, nil, nil, true)
    memory_setraw(address, nil, nil, false)
    ioMemory.GuiCache_InvalidateMemory(address.location .. address.index, 5)
  end
end

function ioMemory.GuiCache_InvalidateMemory(channel, delay)
  if channel then
    if not state.gui_cache.memory_changed then
      state.gui_cache.memory_changed = {}
    end
    if (state.gui_cache.memory_changed[channel] or 0) < game.tick then
      -- do not add cache until gui initialize it
      state.gui_cache.memory_changed[channel] = game.tick + (delay or 0)
      state.gui_cache.memory_autochannel = channel
    end
  else
    -- update all channels
    state.gui_cache.memory_changed = nil
  end
end

function ioMemory.bind(state_)
  state = state_
  output_control = state.cache.control.output
end

function ioMemory.setup(ICStack_, ioRegister_)
  ICStack = ICStack_
  ioRegister = ioRegister_
end

return ioMemory
