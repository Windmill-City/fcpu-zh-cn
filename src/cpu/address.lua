local assert
local control
local wires
local memory
local program_counter
local clock
local address = {}


-- require('constants')
-- {
  NULL_SIGNAL = {signal = nil--[[{ type = "virtual", name = "signal-black" }]], count = 0}
  HALT_SIGNAL = {signal = { type = "virtual", name = "signal-fcpu-halt"}, count = 1}
  RUN_SIGNAL = {signal = { type = "virtual", name = "signal-fcpu-run"}, count = 1}
  STEP_SIGNAL = {signal = { type = "virtual", name = "signal-fcpu-step"}, count = 1}
  SLEEP_SIGNAL = {signal = { type = "virtual", name = "signal-fcpu-sleep"}, count = 1}
  JUMP_SIGNAL = {signal = { type = "virtual", name = "signal-fcpu-jump"}, count = 1}
--
  REG_IPT = MC_MEMORY + 1
  REG_CNR = MC_MEMORY + 2
  REG_CNG = MC_MEMORY + 3
  REG_CLK = MC_MEMORY + 4
-- }


local function readOnlyRegister(index)
  if index == REG_IPT then
    return program_counter
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
  end
end

function address.num(_)
  return _.val
end

function address.memindex(_)
  if _.pointer then
    --assert.memory_index_range(_.val, MC_MEMORY + 4)
    return address.getmem(_, true).count
  else
    return _.val
  end
end

function address.memsize()
  return #memory
end

function address.getraw(index)
  assert.memory_index_range(index, MC_MEMORY)
  return memory[index]
end

function address.setraw(index, signal)
  assert.memory_index_range(index, MC_MEMORY)
  memory[index] = signal
end

function address.getmem(index_expr, ignore_pointer)
  local index
  if not ignore_pointer then
    index = address.memindex(index_expr)
  else
    index = index_expr.val
  end
  if MC_MEMORY < index then
    assert.memory_index_range(index, MC_MEMORY + 4)
    local result = table.deepcopy(NULL_SIGNAL)
    result.count = readOnlyRegister(index)
    return result
  else
    return table.deepcopy(address.getraw(index))
  end
end

function address.setmem(index_expr, value)
  local index = address.memindex(index_expr)
  local signal = table.deepcopy(value)
  address.setraw(index, signal)
end

function address.setmem_count(index_expr, count)
  local value = address.getmem(index_expr)
  value.count = count
  address.setmem(index_expr, value)
end

-- Output Register Helper Functions
function address.getout()
  local signalID = control.parameters.parameters.output_signal
  local value = control.parameters.parameters.first_constant
  return {signal = signalID, count = value}
end

function address.setout(value)
  local params = control.parameters
  params.parameters.first_constant = value.count
  params.parameters.output_signal = value.signal
  control.parameters = params
end

function address.setout_count(count)
  local params = control.parameters
  params.parameters.first_constant = count
  control.parameters = params
end

-- Multiplex Helper Functions
function address.getregister(index_expr)
  if index_expr.location == 'mem' then
    return address.getmem(index_expr)
  elseif index_expr.location == 'out' then
    return address.getout()
  end
end

function address.setregister(index_expr, value)
  if index_expr.location == 'mem' then
    address.setmem(index_expr, value)
  elseif index_expr.location == 'out' then
    address.setout(value)
  end
end

function address.setregister_count(index_expr, count)
  if index_expr.location == 'mem' then
    address.setmem_count(index_expr, count)
  elseif index_expr.location == 'out' then
    address.setout_count(count)
  end
end

function address.const_num(number)
  return {type = "num", val = number}
end

function address.memcount_or_val(_)
  if _.type == 'num' then
    return address.num(_)
  elseif _.type == 'register' and _.location == 'mem' then
    return address.getmem(_).count
  end
end

-- Wire Helper Functions
function address.getwire(_)
  local index = address.memindex(_)
  if not wires[_.color] then
    assert.exception("Tried to access ".._.color.." wire when input not present.")
  end
  if wires[_.color].signals then
    return wires[_.color].signals[index] or NULL_SIGNAL
  end
  return NULL_SIGNAL
end

function address.find_signal_in_wire(wire, signal_to_find)
  if signal_to_find and wire.signals then
    for index, wire_signal in pairs(wire.signals) do
      if wire_signal and wire_signal.signal.name == signal_to_find.signal.name then
        return wire.signals[index]
      end
    end
  end
  return NULL_SIGNAL
end


function address.bind(assert_, control_, wires_, memory_, program_counter_, clock_)
  assert = assert_
  control = control_
  wires = wires_
  memory = memory_
  program_counter = program_counter_
  clock = clock_
end
return address
