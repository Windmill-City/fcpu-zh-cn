local assert
local hdlbuilder
local control
local wires
local state
local io = {}

-- require('constants')
-- {
  NULL_SIGNAL = {signal = nil, count = 0}
  HALT_SIGNAL = {signal = { type = "virtual", name = "signal-fcpu-halt"}, count = 1}
  RUN_SIGNAL = {signal = { type = "virtual", name = "signal-fcpu-run"}, count = 1}
  STEP_SIGNAL = {signal = { type = "virtual", name = "signal-fcpu-step"}, count = 1}
  SLEEP_SIGNAL = {signal = { type = "virtual", name = "signal-fcpu-sleep"}, count = 1}
  JUMP_SIGNAL = {signal = { type = "virtual", name = "signal-fcpu-jump"}, count = 1}
--
  REG_IP = MC_REGS_RO_FIRST + 0
  REG_CNR = MC_REGS_RO_FIRST + 1
  REG_CNG = MC_REGS_RO_FIRST + 2
  REG_CLK = MC_REGS_RO_FIRST + 3
  REG_CNM = MC_REGS_RO_MSLOT
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
  return { type = 'value', count = number }
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
      assert.exception("Can't parse count '".. (countstr or 'nil') .."'")
    end
    return { type = 'signal', signal = signal_id, count = count or 0 }
  end
end

function io.make_register(name, address)
  return { type = 'register', location = name, addr = address.addr, pointer = address.pointer }
end

function io.make_register_ro(addr)
  return { type = 'register', location = 'readonly', addr = tonumber(addr), pointer = false }
end

function io.make_memory(name, index, addr, is_ptr)
  return { type = 'memory', location = name, index = tonumber(index), addr = tonumber(addr), pointer = is_ptr }
end

function io.make_wire(name, address)
  return { type = 'wire', color = name, addr = address.addr, pointer = address.pointer}
end

function io.set_ics(name, index)
  -- same as HdlBuilder.set_ics
  state.ics_stack = state.ics_stack or {}
  state.ics_stack[name] = index
end


-- Address, Value and Signal decomposition
local function addr_deref(_, ignore_pointer)
  assert.check(_.addr ~= nil and _.pointer ~= nil, "Invalid address")
  if _.pointer and not ignore_pointer then
    return io.register_get(_, true).count
  else
    return _.addr
  end
end

function io.value_get(_)
  assert.check(_.type == 'value')
  return _.count
end

function io.signal_name(_)
  assert.check(_.type == 'signal')
  return _.signal.name
end

function io.signal_count(_)
  assert.check(_.type == 'signal')
  return _.signal.count
end


-- Control output
local function control_get()
  local params = control.parameters
  local signal_id = params.parameters.output_signal
  local count = params.parameters.first_constant
  return io.make_signal(signal_id, count)
end

local function control_set(signal)
  local params = control.parameters
  params.parameters.first_constant = signal.count
  params.parameters.output_signal = signal.signal
  control.parameters = params
end


-- Output wire access
local function output_get(index)
  local params = control.parameters
  local signal_id = params.parameters[index].signal
  local count = params.parameters[index].count
  return io.make_signal(signal_id, count)
end

local function output_set(index, signal)
  assert.check(math.abs(signal.count or 0) ~= 1/0, "Division by zero")
  local params = control.parameters
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
    local addr = addr_deref(_)
    return output_get(addr)
  elseif _.type == 'output' then
    assert.todo()
  end
  if not wires[_.color] then
    assert.exception("Tried to access ".._.color.." wire when input not present.")
  end
  if wires[_.color].signals then
    local addr = addr_deref(_)
    return wires[_.color].signals[addr] or NULL_SIGNAL
  end
  return NULL_SIGNAL
end

function io.wire_set(_, signal)
  if _.type == 'wire' and _.color == 'out' then
    local addr = addr_deref(_)
    output_set(addr, signal)
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


-- Registers
local function readOnlyRegister(index)
  if index == REG_IP then
    return state.instruction_pointer
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
    return state.clock
  elseif REG_CNM <= index then
    local node = hdlbuilder.get_node(state, 'mem'.. (index - REG_CNM + 1))
    if node and node.out and node.out.valid then
      local control = node.out.get_control_behavior()
      if control and control.signals_last_tick then
        return #control.signals_last_tick
      end
    end
    return 0
  else
    assert.exception('Unknown register with internal index '.. index)
  end
end

function io.register_last_index()
  return #state.regs
end

function io.register_getraw(index)
  assert.regs_index_range(index, MC_REGS)
  if state.regs[index] and not state.regs[index].count then
    state.regs[index].count = 0
  end
  return state.regs[index]
end

function io.register_setraw(index, signal)
  assert.regs_index_range(index, MC_REGS)
  assert.check(math.abs(signal.count or 0) ~= 1/0, "Division by zero")
  state.regs[index] = signal
end

function io.register_get(index_expr, ignore_pointer)
  local addr = addr_deref(index_expr, ignore_pointer)
  if MC_REGS < addr then
    local result = table.deepcopy(NULL_SIGNAL)
    result.count = readOnlyRegister(addr)
    return result
  else
    return table.deepcopy(io.register_getraw(addr))
  end
end

function io.register_set(index_expr, value)
  local addr = addr_deref(index_expr)
  local signal = table.deepcopy(value)
  io.register_setraw(addr, signal)
end

function io.register_set_count(index_expr, count)
  local value = io.register_get(index_expr)
  assert.check(count == count, "Division by zero")
  value.count = count
  io.register_set(index_expr, value)
end


-- Memory
function io.memory_getraw(channel, index)
  assert.check(1 <= channel and channel <= MC_MEMORY_CHANNELS, "Memory channel is out of range")
  local node = hdlbuilder.get_node(state, "mem" .. channel)
  if node and node.out and node.out.valid then
    local control = node.out.get_control_behavior()
    if control and control.signals_last_tick then
      --assert.check(1 <= index and index <= #control.signals_last_tick, "Memory cell index is out of range")
      return control.signals_last_tick[index]
    end
  else
    assert.exception("Memory channel do not exists yet")
  end
end

function io.memory_get(address)
  assert.check(address.index ~= nil, "Should be addressable memory cell")
  local addr = addr_deref(address)
  return table.deepcopy(io.memory_getraw(address.index, addr))
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
  elseif _.type == 'memory' then
    assert.check(_.location == 'mem', 'expecting location `mem`')
    signal = io.memory_get(_)
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
    assert.check(_.location == 'reg', 'expecting location `reg`')
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
  state = state_
end


function io.bind(assert_, hdlbuilder_)
  assert = assert_
  hdlbuilder = hdlbuilder_
end
return io
