local state
local output_control
local Emitter ---@type Emitter
local ioRegister
local ioChannel
local ioWire = {}

-- Output wire access
local function output_get(index)
  local signal = get_ctrl_slot_signal(output_control, index)
  return Emitter.make_signal(signal.signal, signal.count)
end

local function output_set(index, signal)
  Assert.check(1 <= index and index <= get_ctrl_signals_limit(output_control), "Output cell index is out of range")
  if signal and signal.count and signal.count ~= 0 and signal.signal then
    Assert.check(math.abs(signal.count) ~= 1/0, "Division by zero")
    set_ctrl_slot_signal(output_control, index, signal)
  else
    set_ctrl_slot_signal(output_control, index, nil)
  end
  ioChannel.GuiCache_Invalidate('output', 0)
end

-- General wire manipulation
function ioWire.get(address)
  if address.type == 'wire' and address.color == 'out' then
    local addr = ioRegister.addr_deref(address)
    return output_get(addr)
  elseif address.type == 'output' then
    Assert.todo()
  end
  if not state.cache.wires[address.color] then
    Assert.exception("Tried to access " .. address.color .. " wire when it is not connected")
  end
  if state.cache.wires[address.color].signals then
    local addr = ioRegister.addr_deref(address)
    return state.cache.wires[address.color].signals[addr] or NULL_SIGNAL
  end
  return NULL_SIGNAL
end

function ioWire.set(address, signal)
  if address.type == 'wire' and address.color == 'out' then
    local addr = ioRegister.addr_deref(address)
    output_set(addr, signal)
  elseif address.type == 'output' then
    Assert.todo()
  else
    Assert.todo()
  end
end

function ioWire.find_signal(color, signal_to_find)
  local network = state.cache.wires[color]
  if signal_to_find then
    local count
    if network then
      count = network.get_signal(signal_to_find)
    elseif color == 'input' then
      count = state.entity.get_signal(signal_to_find, defines.wire_connector_id.combinator_input_red, defines.wire_connector_id.combinator_input_green)
    else
      Assert.exception("Tried to access " .. color .. " wire while it is not connected")
    end
    return count
  end
end

function ioWire.count(color)
  return state.cache.wires[color] and state.cache.wires[color].signals and #state.cache.wires[color].signals or 0
end


function ioWire.bind(state_)
  state = state_
  output_control = state_.cache.control.output
end

---@param emitter_ Emitter
function ioWire.setup(emitter_, ioRegister_, ioChannel_)
  Emitter = emitter_
  ioRegister = ioRegister_
  ioChannel = ioChannel_
end

return ioWire
