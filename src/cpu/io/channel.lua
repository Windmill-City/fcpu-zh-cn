local state
local output_control
local ICStack
local ioChannel = {}


-- Channel
function ioChannel.write_control(address)
  if address.type == 'memory' then
    local ics = ICStack.get_node(address.channel)
    if ics.value and ics.value.valid then
      return ics.value.get_control_behavior()
    else
      Assert.exception("Memory channel does not support writing")
    end
  elseif address.type == 'wire' then
    if address.color == 'out' then
      return output_control
    end
    Assert.exception("Could not write to " .. address.color .. " input wire")
  else
    Assert.todo()
  end
end

function ioChannel.read_network(address)
  if address.type == 'memory' or address.type == 'channel' then
    local ics = ICStack.get_node(address.channel)
    if ics.out and ics.out.valid then
      local control = ics.out.get_control_behavior()
      local network = control.get_circuit_network(ics.color_out or defines.wire_type.red, ics.out_connector or defines.circuit_connector_id.combinator_output)
      return network
    else
      if address.type == 'memory' then
        Assert.exception("Memory bank ".. address.channel .." does not exists")
      else
        Assert.exception("Channel ".. address.channel .." does not exists")
      end
    end
  elseif address.type == 'wire' then
    if address.color == 'out' then
      local network = output_control.get_circuit_network(defines.wire_type.red, defines.circuit_connector_id.constant_combinator)
      return network
    end
    if not state.cache.wires[address.color] then
      Assert.exception("Tried to access " .. address.color .. " wire when it is not connected")
    end
    return state.cache.wires[address.color]
  else
    Assert.todo()
  end
end

function ioChannel.output_signals(address)
  local network = ioChannel.read_network(address)
  if address.type == 'memory' then
    return network.signals or {}
  elseif address.type == 'wire' then
    return network.parameters or {}
  end
end

function ioChannel.address_of(address, type)
  local signals = ioChannel.output_signals(address)
  if signals then
    for k, v in ipairs(signals) do
      if v.signal and v.signal.name == type.name and v.signal.type == type.type then
        return k
      end
    end
  end
end

function ioChannel.GuiCache_Invalidate(channel, delay)
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


function ioChannel.bind(state_)
  state = state_
  output_control = state.cache.control.output
end

function ioChannel.setup(ICStack_)
  ICStack = ICStack_
end

return ioChannel
