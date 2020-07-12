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

function io.make_value(number)
  return { type = 'value', val = tonumber(number) }
end

function io.make_address(addr, is_ptr)
  return { type = 'address', addr = tonumber(addr), pointer = is_ptr }
end

function io.make_signal(signal_id, count)
  return { type = 'signal', signal = signal_id, count = tonumber(count) }
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


-- Output Register Helper Functions
local function output_get()
  local signal_id = control.parameters.parameters.output_signal
  local count = control.parameters.parameters.first_constant
  return io.make_signal(signal_id, count)
end

local function output_set(signal)
  local params = control.parameters
  params.parameters.first_constant = signal.count
  params.parameters.output_signal = signal.signal
  control.parameters = params
end

local function output_set_count(count)
  local params = control.parameters
  params.parameters.first_constant = count
  control.parameters = params
end

-- Wire Helper Functions
function io.wire_get(_)
  if _.type == 'wire' and _.color == 'out' or _.type == 'output' then
    return output_get()
  end
  if not wires[_.color] then
    assert.exception("Tried to access ".._.color.." wire when input not present.")
  end
  if wires[_.color].signals then
    local index = io.regsindex(_)
    return wires[_.color].signals[index] or NULL_SIGNAL
  end
  return NULL_SIGNAL
end

function io.wire_set(_, signal)
  if _.type == 'wire' and _.color == 'out' or _.type == 'output' then
    return output_set(signal)
  end
  assert.exception("NOT IMPLEMENTED")
end

function io.wire_find_signal(color, signal_to_find)
  if not wires[color] then
    assert.exception("Tried to access "..color.." wire when input not present.")
  end
  local wire = wires[color]
  if signal_to_find and wire.signals then
    for index, wire_signal in pairs(wire.signals) do
      if wire_signal and wire_signal.signal.name == signal_to_find.signal.name then
        return wire.signals[index]
      end
    end
  end
  return NULL_SIGNAL
end

--
function io.value_get(_) -- used
  assert.check(_.type == 'value')
  return _.val
end

function io.signal_name(_)
  assert.check(_.type == 'signal')
  return _.name
end

function io.signal_count(_)
  assert.check(_.type == 'signal')
  return _.count
end

function io.register_get(index)
  assert.regs_index_range(index, MC_REGS)
  return regs[index]
end

function io.register_set(index, signal)
  assert.regs_index_range(index, MC_REGS)
  regs[index] = signal
end

-- Registers
function io.regsindex(_)
  if _.pointer then
    --assert.regs_index_range(_.addr, MC_REGS + 4)
    return io.regsget(_, true).count
  else
    return _.addr
  end
end

function io.regssize() -- used
  return #regs
end

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

function io.regsget(index_expr, ignore_pointer)
  local index
  if not ignore_pointer then
    index = io.regsindex(index_expr)
  else
    index = index_expr.val
  end
  if MC_REGS < index then
    assert.regs_index_range(index, MC_REGS + 4)
    local result = table.deepcopy(NULL_SIGNAL)
    result.count = readOnlyRegister(index)
    return result
  else
    return table.deepcopy(io.register_get(index))
  end
end

function io.regsset(index_expr, value)
  local index = io.regsindex(index_expr)
  local signal = table.deepcopy(value)
  io.register_set(index, signal)
end

function io.regsset_count(index_expr, count)
  local value = io.regsget(index_expr)
  value.count = count
  io.regsset(index_expr, value)
end

-- Multiplex Helper Functions
function io.getregister(index_expr)
  if index_expr.location == 'reg' then
    return io.regsget(index_expr)
  elseif index_expr.color == 'out' then
    return output_get()
  else
    assert.exception('unhandler')
  end
end

function io.setregister(index_expr, value)
  if index_expr.location == 'reg' then
    io.regsset(index_expr, value)
  elseif index_expr.color == 'out' then
    output_set(value)
  else
    assert.exception('unhandler')
  end
end

function io.setregister_count(index_expr, count)
  if index_expr.location == 'readonly' then
    io.regsset_count(index_expr, count)
  elseif index_expr.color == 'out' then
    output_set_count(count)
  else
    assert.exception('unhandler')
  end
end

-- Signal Functions
function io.getsignal(_, types) -- used
  if not types then
    types = {'signal', 'register', 'wire'}
  end
  assert.type(_, types)
  local signal = nil
  if _.type == 'wire' or _.type == 'input' then
    signal = io.wire_get(_)
  elseif _.type == 'register' then
    signal = io.getregister(_)
  elseif _.type == 'signal' then
    signal = _
  else
    assert.exception('unhandler')
  end
  return signal
end

function io.getcount(_, types)
  if _.type == 'value' then
    return io.value_get(_)
  else
    local signal = io.getsignal(_, types)
    if type(signal) ~= 'table' or signal.count == nil then
      assert.exception('unhandled')
    end
    return signal.count
  end
end

function io.setsignal(_, signal, types) -- used
  if not types then
    types = {'register', 'wire'}
  end
  assert.type(_, types)
  if _.type == 'wire' or _.type == 'output' then
    io.wire_set(_, signal)
  elseif _.type == 'register' then
    io.setregister(_, signal)
  else
    assert.exception('unhandler')
  end
end



function io.bind(assert_, control_, wires_, regs_, instruction_pointer_, clock_)
  assert = assert_
  control = control_
  wires = wires_
  regs = regs_
  instruction_pointer = instruction_pointer_
  clock = clock_
end
return io
