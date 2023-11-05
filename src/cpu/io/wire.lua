local state
local output_control
local ioRegister
local ioMemory
local emitter
local ioWire = {}

-- Output wire access
local function output_get(index)
  local signal = output_control.get_signal(index)
  return emitter.make_signal(signal.signal, signal.count)
end

local function output_set(index, signal)
  Assert.check(1 <= index and index <= MC_OUTPUT, "Output cell index is out of range")
  if signal and signal.count and signal.count ~= 0 and signal.signal then
    Assert.check(math.abs(signal.count) ~= 1/0, "Division by zero")
    output_control.set_signal(index, signal)
  else
    output_control.set_signal(index, nil)
  end
  ioMemory.GuiCache_InvalidateMemory('output', 0)
end

-- General wire manipulation
function ioWire.get(_)
  if _.type == 'wire' and _.color == 'out' then
    local addr = ioRegister.addr_deref(_)
    return output_get(addr)
  elseif _.type == 'output' then
    Assert.todo()
  end
  if not state.cache.wires[_.color] then
    Assert.exception("Tried to access " .. _.color .. " wire when it is not connected")
  end
  if state.cache.wires[_.color].signals then
    local addr = ioRegister.addr_deref(_)
    return state.cache.wires[_.color].signals[addr] or NULL_SIGNAL
  end
  return NULL_SIGNAL
end

function ioWire.set(_, signal)
  if _.type == 'wire' and _.color == 'out' then
    local addr = ioRegister.addr_deref(_)
    output_set(addr, signal)
  elseif _.type == 'output' then
    Assert.todo()
  else
    Assert.todo()
  end
end

function ioWire.find_signal(color, signal_to_find)
  local wire = state.cache.wires[color]
  if signal_to_find then
    local count
    if wire then
      count = wire.get_signal(signal_to_find)
    elseif color == 'input' then
      count = state.entity.get_merged_signal(signal_to_find, defines.circuit_connector_id.combinator_input)
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

function ioWire.setup(ioRegister_, ioMemory_, emitter_)
  ioRegister = ioRegister_
  ioMemory = ioMemory_
  emitter = emitter_
end

return ioWire
