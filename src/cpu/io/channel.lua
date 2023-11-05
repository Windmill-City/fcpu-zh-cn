local state
local output_control
local ICStack
local ioChannel = {}


-- Channel
function ioChannel.read(address)
  if address.type == 'memory' then
    local ics = ICStack.get_node(state, address.channel)
    if ics and ics.out and ics.out.valid then
      local control = ics.out.get_control_behavior()
      local network = control.get_circuit_network(ics.color_out or defines.wire_type.red,
        defines.circuit_connector_id.combinator_output)
      return network or control
    else
      Assert.exception("Memory channel does not exists")
    end
  elseif address.type == 'wire' then
    if address.color == 'out' then
      return output_control.get_circuit_network(defines.wire_type.red, defines.circuit_connector_id.constant_combinator)
    end
    if not state.cache.wires[address.color] then
      Assert.exception("Tried to access " .. address.color .. " wire when it is not connected")
    end
    return state.cache.wires[address.color]
  else
    Assert.todo()
  end
end

function ioChannel.write(address, corrective)
  if address.type == 'memory' then
    local ics = ICStack.get_node(state, address.channel)
    if ics then
      if corrective then
        if ics.value2 and ics.value2.valid then
          return ics.value2.get_control_behavior()
        end
      else
        if ics.value and ics.value.valid then
          ioChannel.GuiCache_InvalidateMemory(address.channel, 5)
          return ics.value.get_control_behavior()
        end
      end
    end
    Assert.exception("Memory channel does not support writing")
  elseif address.type == 'wire' then
    if address.color == 'out' then
      return output_control
    end
    Assert.exception("Could not write to " .. address.color .. " input wire")
  else
    Assert.todo()
  end
end

function ioChannel.signals(address)
  -- DEPRECATED
  if address.type == 'memory' then
    local ics = ICStack.get_node(state, address.channel)
    if ics and ics.out and ics.out.valid then
      local control = ics.out.get_control_behavior()
      local output = control.get_circuit_network(ics.color_out or defines.wire_type.red,
        defines.circuit_connector_id.combinator_output)
      return output and output.signals or control.signals_last_tick or {}
    else
      Assert.exception("Memory channel does not exists")
    end
  elseif address.type == 'wire' then
    if address.color == 'out' then
      return output_control.parameters
    end
    if not state.cache.wires[address.color] then
      Assert.exception("Tried to access " .. address.color .. " wire when it is not connected")
    end
    return state.cache.wires[address.color].signals or {}
  else
    Assert.todo()
  end
end

function ioChannel.GuiCache_InvalidateMemory(channel, delay)
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
