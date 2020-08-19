local assert
local control
local wires
local regs
local instruction_pointer
local clock
local io = {}


-- require('constants')
-- {
  NULL_SIGNAL = {signal = nil--[[{ type = "virtual", name = "signal-black" }]], count = 0}
  HALT_SIGNAL = {signal = { type = "virtual", name = "signal-fcpu-halt"}, count = 1}
  RUN_SIGNAL = {signal = { type = "virtual", name = "signal-fcpu-run"}, count = 1}
  STEP_SIGNAL = {signal = { type = "virtual", name = "signal-fcpu-step"}, count = 1}
  SLEEP_SIGNAL = {signal = { type = "virtual", name = "signal-fcpu-sleep"}, count = 1}
  JUMP_SIGNAL = {signal = { type = "virtual", name = "signal-fcpu-jump"}, count = 1}
--
  REG_IP = MC_REGS + 1
  REG_CNR = MC_REGS + 2
  REG_CNG = MC_REGS + 3
  REG_CLK = MC_REGS + 4
-- }

-- Makers
function io.make_label(label)
  return { type = 'label', label = label }
end

function io.make_value(numstr, fixedpoint)
  local number = tonumber(numstr)
  if number == nil then
    assert.exception("Can't parse number '".. numstr .."'")
  end
  if fixedpoint then
    return { type = 'value', count = number * MC_FIXEDPOINT, fixedpoint = true }
  else
    return { type = 'value', count = number }
  end
end

function io.make_address(addr, is_ptr)
  assert.check(addr ~= nil)
  return { type = 'address', addr = tonumber(addr), pointer = is_ptr }
end

function io.make_signal(signal_id, countstr)
  if countstr == '' then
    return { type = 'type', signal = signal_id }
  else
    local count = tonumber(countstr)
    if count == nil then
      assert.exception("Can't parse count '".. countstr .."'")
    end
    return { type = 'signal', signal = signal_id, count = count }
  end
end

function io.make_register(name, address)
  return { type = 'register', location = name, addr = address.addr, pointer = address.pointer }
end

function io.make_register_ro(addr)
  return { type = 'register', location = 'readonly', addr = tonumber(addr), pointer = false }
end

function io.make_memory(name, address)
  return { type = 'memory', location = name, addr = address.addr, pointer = address.pointer }
end

function io.make_wire(name, address)
  return { type = 'wire', color = name, addr = address.addr, pointer = address.pointer}
end


-- Output wire access
local function output_get(index)
  local params = control.parameters
  --local signal_id = params.parameters.output_signal
  --local count = params.parameters.first_constant
  --return io.make_signal(signal_id, count)
  local signal_id = params.parameters[index].signal
  local count = params.parameters[index].count
  return io.make_signal(signal_id, count)
end

local function output_set(index, signal)
  local params = control.parameters
  --params.parameters.first_constant = signal.count
  --params.parameters.output_signal = signal.signal
  params.parameters[index].signal = signal.signal
  params.parameters[index].count = signal.count
  params.parameters[index].index = index
  control.parameters = params
end

function io.output_clear()
  control.parameters = nil
end

-- General wire manipulation
function io.wire_get(_)
  if _.type == 'wire' and _.color == 'out' then
    local index = io.addr_to_index(_)
    return output_get(index)
  elseif _.type == 'output' then
    assert.todo()
  end
  if not wires[_.color] then
    assert.exception("Tried to access ".._.color.." wire when input not present.")
  end
  if wires[_.color].signals then
    local index = io.addr_to_index(_)
    return wires[_.color].signals[index] or NULL_SIGNAL
  end
  return NULL_SIGNAL
end

function io.wire_set(_, signal)
  if _.type == 'wire' and _.color == 'out' then
    local index = io.addr_to_index(_)
    output_set(index, signal)
  elseif _.type == 'output' then
    assert.todo()
  else
    assert.todo()
  end
end

function io.wire_find_signal(color, signal_to_find)
  if not wires[color] then
    assert.exception("Tried to access "..color.." wire when input not present.")
  end
  local wire = wires[color]
  if signal_to_find and wire.signals then
    for index, wire_signal in pairs(wire.signals) do
      if wire_signal and wire_signal.signal.name == signal_to_find.name then
        return wire.signals[index]
      end
    end
  end
  return NULL_SIGNAL
end

function io.wire_count(color)
  return wires[color] and wires[color].signals and #wires[color].signals or 0
end

-- Address, Value and Signal decomposition
function io.addr_to_index(_, ignore_pointer)
  assert.check(_.addr ~= nil and _.pointer ~= nil)
  if _.pointer and not ignore_pointer then
    return io.register_get(_, true).count
  else
    return _.addr
  end
end

function io.value_get(_)
  assert.check(_.type == 'value')
  if _.fixedpoint then
    return _.count / MC_FIXEDPOINT
  else
    return _.count
  end
end

function io.signal_name(_)
  assert.check(_.type == 'signal')
  return _.signal.name
end

function io.signal_count(_)
  assert.check(_.type == 'signal')
  return _.signal.count
end

-- Registers
local function readOnlyRegister(index)
  if index == REG_IP then
    return instruction_pointer
  elseif index == REG_CNR then
    if wires.red and wires.red.signals then
      return #wires.red.signals
    else
      return 0
    end
  elseif index == REG_CNG then
    if wires.green and wires.green.signals then
      return #wires.green.signals
    else
      return 0
    end
  elseif index == REG_CLK then
    return clock
  else
    assert.exception('unhandler')
  end
end

function io.register_last_index()
  return #regs
end

function io.register_getraw(index)
  assert.regs_index_range(index, MC_REGS)
  return regs[index]
end

function io.register_setraw(index, signal)
  assert.regs_index_range(index, MC_REGS)
  regs[index] = signal
end

function io.register_get(index_expr, ignore_pointer)
  local index = io.addr_to_index(index_expr, ignore_pointer)
  if MC_REGS < index then
    assert.regs_index_range(index, MC_REGS + 4)
    local result = table.deepcopy(NULL_SIGNAL)
    result.count = readOnlyRegister(index)
    return result
  else
    return table.deepcopy(io.register_getraw(index))
  end
end

function io.register_set(index_expr, value)
  local index = io.addr_to_index(index_expr)
  local signal = table.deepcopy(value)
  io.register_setraw(index, signal)
end

function io.register_set_count(index_expr, count)
  local value = io.register_get(index_expr)
  if count ~= count then
    assert.exception("Division by zero")
  end
  value.count = count
  value.fixedpoint = false
  io.register_set(index_expr, value)
end

function io.register_set_fp(index_expr, count)
  local value = io.register_get(index_expr)
  value.count = count * MC_FIXEDPOINT
  value.fixedpoint = true
  io.register_set(index_expr, value)
end

-- Multiplex Helper Functions
function io.getsignal(_, types)
  if not types then
    types = {'signal', 'register', 'wire'}
  end
  assert.type(_, types)
  local signal = nil
  if _.type == 'wire' or _.type == 'input' then
    signal = io.wire_get(_)
  elseif _.type == 'register' then
    signal = io.register_get(_)
  elseif _.type == 'signal' or _.type == 'type' or _.type == 'value' then
    signal = _
  else
    assert.exception('tryint to retrieve nil signal')
  end
  return signal
end

function io.setsignal(_, signal, types)
  if not types then
    types = {'register', 'wire'}
  end
  assert.type(_, types)
  if _.type == 'wire' then 
    io.wire_set(_, signal)
  elseif _.type == 'register' then
    io.register_set(_, signal)
  elseif _.type == 'output' then
    assert.todo()
  else
    assert.exception('unhandled')
  end
end


function io.getcount(_, types)
  if _.type == 'value' then
    return io.value_get(_)
  else
    local signal = io.getsignal(_, types)
    if type(signal) ~= 'table' or signal.count == nil then
      assert.exception('tryint to retrieve nil count')
    end
    return signal.count
  end
end

function io.setcount(_, count, types)
  -- TODO: optimize
  local signal = io.getsignal(_, types)
  signal.count = count
  io.setsignal(_, signal, types)
end


function io.gettype(_, types)
  local signal = io.getsignal(_, types)
  if type(signal) ~= 'table' or signal.signal == nil then
    assert.exception('tryint to retrieve nil type')
  end
  return signal.signal
end

function io.settype(_, sigtype, types)
  -- TODO: optimize
  local signal = io.getsignal(_, types)
  signal.signal = sigtype
  io.setsignal(_, signal, types)
end



function io.bind(assert_)
  assert = assert_
end
function io.setup(control_, state_)
  wires = {
    red = control_.get_circuit_network(defines.wire_type.red, defines.circuit_connector_id.combinator_input),
    green = control_.get_circuit_network(defines.wire_type.green, defines.circuit_connector_id.combinator_input),
  }

  if state_.output_fcpu then
    control = state_.output_fcpu.get_control_behavior()
  else
    assert.todo()
    control = control_
  end
  regs = state_.regs
  instruction_pointer = state_.instruction_pointer
  clock = state_.clock
end
return io
