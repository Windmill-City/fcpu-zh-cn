local assert
local hdlbuilder
local control_out
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


-- Address, Value and Signal decomposition
local function addr_deref(_)
  assert.check(_.addr ~= nil and _.pointer ~= nil, "Invalid address")
  if _.pointer then
    assert.check(_.addr <= MC_REGS)
    return io.register_getraw(_.addr).count
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
function io.control_get()
  local params = control.parameters
  local signal_id = params.parameters.output_signal
  local count = params.parameters.first_constant
  return io.make_signal(signal_id, count)
end

function io.control_set(signal)
  local params = control.parameters
  params.parameters.first_constant = signal.count
  params.parameters.output_signal = signal.signal
  control.parameters = params
end


-- Output wire access
local function output_get(index)
  local signal = control_out.get_signal(index)
  return io.make_signal(signal.signal, signal.count)
end

local function output_set(index, signal)
  assert.check(math.abs(signal and signal.count or 0) ~= 1/0, "Division by zero")
  control_out.set_signal(index, signal)
end

function io.output_clear()
  control_out.parameters = nil
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
  if signal_to_find then
    local count = wire.get_signal(signal_to_find)
    if count ~= 0 then
      return {signal = signal_to_find, count = count}
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
    local signals = io.memory_getchannel_signals(index - REG_CNM + 1)
    return signals and #signals or 0
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

function io.register_get(index_expr)
  assert.check(index_expr.type == 'register', "Register expected")
  local addr = addr_deref(index_expr)
  if MC_REGS < addr then
    local result = table.deep_copy(NULL_SIGNAL)
    result.count = readOnlyRegister(addr)
    return result
  else
    return table.deep_copy(io.register_getraw(addr))
  end
end

function io.register_set(index_expr, value)
  assert.check(index_expr.type == 'register', "Register expected")
  local addr = addr_deref(index_expr)
  local signal = table.deep_copy(value)
  io.register_setraw(addr, signal)
end

function io.register_set_count(index_expr, count)
  local value = io.register_get(index_expr)
  assert.check(count == count, "Division by zero")
  value.count = count
  io.register_set(index_expr, value)
end


-- Memory
function io.get_node(name)
  -- same as HdlBuilder.get_node
  return state.program_ics[state.ics_stack[name]]
end

function io.set_ics(name, index)
  -- same as HdlBuilder.set_ics
  state.ics_stack[name] = index
end

function io.each_ics(proc, name)
  local index = name and state.ics_stack[name]
  for k, ics in pairs(state.program_ics) do
    if type(k) == 'number' then
      if not index or k == index then
        proc(ics)
      end
    end
  end
end

function io.ics_control(index)
  local ics = state.program_ics[index]
  return ics, ics and ics.get_or_create_control_behavior()
end

function io.memory_getchannel_control(_)
  if _.type == 'memory' then
    local ics = hdlbuilder.get_node(state, _.location .. _.index)
    if ics and ics.out and ics.out.valid then
      local control = ics.out.get_control_behavior()
      local network = control.get_circuit_network(ics.color_out or defines.wire_type.red, defines.circuit_connector_id.combinator_output)
      return network or control
    else
      assert.exception("Memory channel does not exists")
    end
  elseif _.type == 'wire' then
    if _.color == 'out' then
      return control_out
    end
    if not wires[_.color] then
      assert.exception("Tried to access ".._.color.." wire when input not present.")
    end
    return wires[_.color]
  else
    assert.todo()
  end
end

function io.memory_getchannel_signals(_)
  if type(_) == 'number' then
    local channel = _
    assert.check(1 <= channel and channel <= MC_MEMORY_CHANNELS, "Memory channel is out of range")
    local ics = hdlbuilder.get_node(state, "mem" .. channel)
    if ics and ics.out and ics.out.valid then
      local control = ics.out.get_control_behavior()
      if ics.color_out then
        local output = control.get_circuit_network(ics.color_out, defines.circuit_connector_id.combinator_output)
        if output then
          return output.signals
        end
      end
      return control.signals_last_tick
    else
      assert.exception("Memory channel does not exists")
    end
  elseif _.type == 'wire' then
    if _.color == 'out' then
      return control_out.parameters.parameters
    end
    if not wires[_.color] then
      assert.exception("Tried to access ".._.color.." wire when input not present.")
    end
    return wires[_.color].signals
  else
    assert.todo()
  end
end

function io.memory_getraw(channel, index)
  local signals = io.memory_getchannel_signals(channel)
  assert.check(signals ~= nil, "Trying to retrieve nil memory cell")
  assert.check(1 <= index and index <= #signals, "Memory cell index is out of range")
  return signals[index] or NULL_SIGNAL
end

function io.memory_get(address)
  assert.check(address.index ~= nil, "Should be addressable memory cell")
  local addr = addr_deref(address)
  return table.deep_copy(io.memory_getraw(address.index, addr))
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
  elseif _.type == 'memory' then
    assert.exception('Memory cell could not be changed. Not supported yet.')
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


function io.setup(state_, control_)
  state = state_
  control = control_

  wires = {
    red = control_.get_circuit_network(defines.wire_type.red, defines.circuit_connector_id.combinator_input),
    green = control_.get_circuit_network(defines.wire_type.green, defines.circuit_connector_id.combinator_input),
  }

  if state_.program_ics.output and state_.program_ics.output.valid then
    control_out = state_.program_ics.output.get_control_behavior()
  end
end


function io.bind(assert_, hdlbuilder_)
  assert = assert_
  hdlbuilder = hdlbuilder_
end
return io
