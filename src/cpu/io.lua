local Assert = require('src/cpu/assert')
local Controller
local hdlbuilder
local emitter
local indication_control
local output_control
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


function io.for_entity(proc)
  return proc(state.entity, state)
end

function io.add_deferred(deffer)
  Controller.add_deferred(state, deffer)
end


-- Registers
local function register_getreadonly(index)
  if index == REG_IP then
    return state.instruction_pointer
  elseif index == REG_CNR then
    if state.cache.wires.red and state.cache.wires.red.signals then
      return #state.cache.wires.red.signals
    else
      return 0
    end
  elseif index == REG_CNG then
    if state.cache.wires.green and state.cache.wires.green.signals then
      return #state.cache.wires.green.signals
    else
      return 0
    end
  elseif index == REG_CLK then
    return state.clock
  elseif REG_CNM <= index then
    local signals = io.memory_getchannel_signals({ type = 'memory', location = 'mem', index = index - REG_CNM + 1 })
    return signals and #signals or 0
  else
    Assert.exception('Unknown register with internal index '.. index)
  end
end

local function register_getraw(index)
  Assert.regs_index_range(index, MC_REGS)
  if state.regs[index] and not state.regs[index].count then
    state.regs[index].count = 0
  end
  return state.regs[index]
end

local function register_setraw(index, signal)
  Assert.regs_index_range(index, MC_REGS)
  Assert.check(math.abs(signal.count or 0) ~= 1/0, "Division by zero")
  state.regs[index] = signal
end

local function addr_deref(_)
  Assert.check(_.addr ~= nil and _.pointer ~= nil, "Invalid address")
  if _.pointer then
    Assert.check(_.addr <= MC_REGS)
    return register_getraw(_.addr).count
  else
    return _.addr
  end
end


function io.register_get(index_expr)
  Assert.check(index_expr.type == 'register', "Register expected")
  local addr = addr_deref(index_expr)
  if MC_REGS < addr then
    local result = table.deep_copy(NULL_SIGNAL)
    result.count = register_getreadonly(addr)
    return result
  else
    return table.deep_copy(register_getraw(addr))
  end
end

function io.register_set(index_expr, value)
  Assert.check(index_expr.type == 'register', "Register expected")
  local addr = addr_deref(index_expr)
  local signal = table.deep_copy(value)
  register_setraw(addr, signal)
end

function io.register_set_count(index_expr, count)
  local value = io.register_get(index_expr)
  Assert.check(count == count, "Division by zero")
  value.count = count
  io.register_set(index_expr, value)
end


-- Control output
function io.control_get()
  local params = indication_control.parameters
  local signal_id = params.output_signal
  local count = params.first_constant
  return emitter.make_signal(signal_id, count)
end

function io.control_set(signal)
  local params = indication_control.parameters
  params.first_constant = signal.count
  params.output_signal = signal.signal
  indication_control.parameters = params
end


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
  io.GuiCache_InvalidateMemory('output', 0)
end

function io.output_clear()
  -- Output buffer
  output_control.parameters = nil
  io.GuiCache_InvalidateMemory('output', 0)

  -- Vector output
  local ast = io.get_node_ast('output')
  if ast and ast.deffer and ast.deffer.clr then
    return { type = 'deffer', deffer = ast.deffer.clr }
  end
end


-- General wire manipulation
function io.wire_get(_)
  if _.type == 'wire' and _.color == 'out' then
    local addr = addr_deref(_)
    return output_get(addr)
  elseif _.type == 'output' then
    Assert.todo()
  end
  if not state.cache.wires[_.color] then
    Assert.exception("Tried to access ".._.color.." wire when it is not connected")
  end
  if state.cache.wires[_.color].signals then
    local addr = addr_deref(_)
    return state.cache.wires[_.color].signals[addr] or NULL_SIGNAL
  end
  return NULL_SIGNAL
end

function io.wire_set(_, signal)
  if _.type == 'wire' and _.color == 'out' then
    local addr = addr_deref(_)
    output_set(addr, signal)
  elseif _.type == 'output' then
    Assert.todo()
  else
    Assert.todo()
  end
end

function io.wire_find_signal(color, signal_to_find)
  local wire = state.cache.wires[color]
  if signal_to_find then
    local count
    if wire then
      count = wire.get_signal(signal_to_find)
    elseif color == 'input' then
      count = state.entity.get_merged_signal(signal_to_find, defines.circuit_connector_id.combinator_input)
    else
      Assert.exception("Tried to access "..color.." wire when it is not connected")
    end
    return count
  end
end

function io.wire_count(color)
  return state.cache.wires[color] and state.cache.wires[color].signals and #state.cache.wires[color].signals or 0
end


-- Memory
function io.ics_set(name, index)
  state.ics_stack[name] = index
end

function io.get_node_ast(name)
  local index = state.ics_stack[name]
  return state.program_ast[index]
end

function io.ics_each_ast(proc, name)
  if name then
    local index = state.ics_stack[name]
    local ast = state.program_ast[index]
    if ast then
      proc(ast)
    end
  else
    for k in pairs(state.program_ics) do
      if type(k) == 'number' then
        proc(state.program_ast[k])
      end
    end
  end
end

function io.memory_getchannel_read(_)
  if _.type == 'memory' then
    local ics = hdlbuilder.get_node(state, _.location .. _.index)
    if ics and ics.out and ics.out.valid then
      local control = ics.out.get_control_behavior()
      local network = control.get_circuit_network(ics.color_out or defines.wire_type.red, defines.circuit_connector_id.combinator_output)
      return network or control
    else
      Assert.exception("Memory channel does not exists")
    end
  elseif _.type == 'wire' then
    if _.color == 'out' then
      return output_control.get_circuit_network(defines.wire_type.red, defines.circuit_connector_id.constant_combinator)
    end
    if not state.cache.wires[_.color] then
      Assert.exception("Tried to access ".._.color.." wire when it is not connected")
    end
    return state.cache.wires[_.color]
  else
    Assert.todo()
  end
end

function io.memory_getchannel_write(_, corrective)
  if _.type == 'memory' then
    local ics = hdlbuilder.get_node(state, _.location .. _.index)
    if ics then
      if corrective then
        if ics.value2 and ics.value2.valid then
          return ics.value2.get_control_behavior()
        end
      else
        if ics.value and ics.value.valid then
          io.GuiCache_InvalidateMemory(_.location .. _.index, 5)
          return ics.value.get_control_behavior()
        end
      end
    end
    Assert.exception("Memory channel does not support writing")
  elseif _.type == 'wire' then
    if _.color == 'out' then
      return output_control
    end
    Assert.exception("Could not write to ".._.color.." input wire")
  else
    Assert.todo()
  end
end

function io.memory_getchannel_signals(_)
  -- DEPRECATED
  if _.type == 'memory' then
    local ics = hdlbuilder.get_node(state, _.location .. _.index)
    if ics and ics.out and ics.out.valid then
      local control = ics.out.get_control_behavior()
      local output = control.get_circuit_network(ics.color_out or defines.wire_type.red, defines.circuit_connector_id.combinator_output)
      return output and output.signals or control.signals_last_tick or {}
    else
      Assert.exception("Memory channel does not exists")
    end
  elseif _.type == 'wire' then
    if _.color == 'out' then
      return output_control.parameters
    end
    if not state.cache.wires[_.color] then
      Assert.exception("Tried to access ".._.color.." wire when it is not connected")
    end
    return state.cache.wires[_.color].signals or {}
  else
    Assert.todo()
  end
end

local function memory_getraw(channel, addr)
  local signals = io.memory_getchannel_signals(channel)
  --Assert.check(signals ~= nil, "Trying to retrieve nil memory channel")
  return signals and signals[addr] or NULL_SIGNAL
end

local function memory_setraw(channel, addr, signal, corrective)
  local control = io.memory_getchannel_write(channel, corrective)
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
      Assert.check(math.abs(signal.count) ~= 1/0, "Division by zero")
      control.set_signal(addr, signal)
    else
      control.set_signal(addr, nil)
    end
  end
end

function io.memory_get(address)
  Assert.check(address.index ~= nil, "Should be addressable memory cell")
  local addr = addr_deref(address)
  return table.deep_copy(memory_getraw(address, addr))
end

function io.memory_set(address, signal)
  Assert.check(address.index ~= nil, "Should be addressable memory cell")
  local addr = addr_deref(address)
  local was = memory_getraw(address, addr)
  if was and was.signal then
    was = table.deep_copy(was)
    was.count = -was.count;
    memory_setraw(address, addr, was, true)
  end
  if signal.count ~= 0 then
    memory_setraw(address, addr, signal)
  end
  io.GuiCache_InvalidateMemory(address.location .. address.index, 5)
end

function io.memory_clear(address)
  if address == nil or address.index == nil then
    for i = 1, MC_MEMORY_CHANNELS do
      io.memory_clear{type='memory', location='mem', index=i}
    end
  else
    Assert.check(address.addr == nil, "Should be a memory channel")
    memory_setraw(address, nil, nil, true)
    memory_setraw(address, nil, nil, false)
    io.GuiCache_InvalidateMemory(address.location .. address.index, 5)
  end
end

function io.GuiCache_InvalidateMemory(channel, delay)
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


-- Multiplex Helper Functions
function io.getsignal(_, types)
  if not types then
    types = {'signal', 'register', 'wire'}
  end
  Assert.type(_, types)
  local signal = nil
  if _.type == 'wire' or _.type == 'input' then
    signal = io.wire_get(_)
  elseif _.type == 'register' then
    signal = io.register_get(_)
  elseif _.type == 'memory' then
    Assert.check(_.location == 'mem', 'expecting location `mem`')
    signal = io.memory_get(_)
  elseif _.type == 'signal' or _.type == 'type' or _.type == 'value' then
    signal = _
  elseif _.type == 'string' then
    Assert.exception('not supported yet')
  else
    Assert.exception('trying to retrieve nil signal')
  end
  return signal
end

function io.setsignal(_, signal, types)
  if not types then
    types = {'register', 'wire'}
  end
  Assert.type(_, types)
  if _.type == 'wire' then
    io.wire_set(_, signal)
  elseif _.type == 'register' then
    Assert.check(_.location == 'reg', 'expecting location `reg`')
    io.register_set(_, signal)
  elseif _.type == 'memory' then
    io.memory_set(_, signal)
    --Assert.exception('Memory cell could not be changed. Not supported yet.')
  elseif _.type == 'output' then
    Assert.todo()
  else
    Assert.exception('unhandled')
  end
end


function io.getvalue(_, types)
  if _.type == 'value' then
    local t = types and Assert.type(_, types)
    return _.count
  elseif _.type == 'string' then
    local t = types and Assert.type(_, types)
    return _.str
  else
    local signal = io.getsignal(_, types)
    if type(signal) == 'table' then
      local value = signal.str or signal.count
      if value then
        return value
      end
    end
    Assert.exception('trying to retrieve nil count')
  end
end

function io.setcount(_, count, types)
  -- TODO: optimize
  local signal = io.getsignal(_, types)
  signal.str = nil
  signal.count = count
  io.setsignal(_, signal, types)
end


function io.gettype(_, types)
  local signal = io.getsignal(_, types)
  if type(signal) ~= 'table' or signal.signal == nil then
    Assert.exception('trying to retrieve nil type')
  end
  return signal.signal
end

function io.settype(_, sigtype, types)
  -- TODO: optimize
  local signal = io.getsignal(_, types)
  signal.signal = sigtype
  io.setsignal(_, signal, types)
end


function io.bind(state_)
  state = state_
  output_control = state_.cache.control.output
  indication_control = state_.cache.control.indication
end


function io.setup(hdlbuilder_, emitter_, controller_)
  Controller = controller_
  hdlbuilder = hdlbuilder_
  emitter = emitter_
end
return io
