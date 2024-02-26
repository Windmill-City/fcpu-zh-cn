local World = require('__stdlib__/faketorio/world')
World.init()


Heap = require('../src/utils/Heap')
Entity = require('__stdlib__/stdlib/entity/entity')
table = require('__stdlib__/stdlib/utils/table')
Heap = require('../src/utils/Heap')

require('../src/constants')
require('../src/storage')
Controller = require('../src/cpu/controller')
Assert = require('../src/cpu/assert')

----------------------------------------------------------------------------------------------------------------

function init_globals()
  World.init()

  global.gui_update_on_tick = 0
  global.unmap = {}
  global.destroy = {}
  global.fcpus = {}
  global.running = {}
  global.deffered = Heap.new()

  unit_number = 0
end

script.register_on_object_destroyed = function(ent)
  ent.valid = true
  return unit_number
end

-- Init global variables
global = global or {}
global.gui_update_on_tick = 0
global.unmap = {}
global.destroy = {}
global.fcpus = {}
global.running = {}
global.deffered = Heap.new()

function createFCPU(input)
  local fcpu = table.deep_copy(require('__stdlib__/faketorio/raw/arithmetic-combinator')['arithmetic-combinator'])
  unit_number = unit_number + 1
  fcpu.unit_number = unit_number
  fcpu.name = 'fcpu'
  fcpu.get_control_behavior = function()
    return fcpu._control_behavior
  end

  fcpu.is_connected_to_electric_network = function()
    return true
  end

  fcpu.surface = {
    create_entity = function(params)
      return Entity.create_entity(params)
    end
  }

  fcpu.energy = 1000
  fcpu.electric_buffer_size = fcpu.energy

  local MakeBus = function(bus)
    local signals = {}
    local out = {
      signals = signals,
      get_signal = function(signal)
        for _, v in ipairs(signals or {}) do
          if v.signal.type == signal.type and v.signal.name == signal.name then
            return v.count
          end
        end
        return 0
      end
    }
    if bus then
      for _, s in pairs(bus) do
        local k, v
        for k_,v_ in pairs(s) do
          k = k_
          v = v_
          break
        end
        local t, n = string.match(k, '(%a+)=([%a%d%-]+)')
        table.insert(signals, { signal = { type = t, name = n }, count = v })
      end
    end
    return out
  end
  local buses = {
    [defines.wire_type.green] = MakeBus(input[defines.wire_type.green]),
    [defines.wire_type.red] = MakeBus(input[defines.wire_type.red]),
  }

  fcpu.get_merged_signal = function(signal)
    local control = fcpu.get_control_behavior()
    return
      control.get_circuit_network(defines.wire_type.green).get_signal(signal)
    + control.get_circuit_network(defines.wire_type.red).get_signal(signal)
  end
  fcpu.get_or_create_control_behavior = function()
    if fcpu._control_behavior == nil then
      fcpu._control_behavior = {
        first_signal = nil,
        second_signal = nil,
        first_constant = nil,
        second_constant = nil,
        operation = "*",
        output_signal = nil,

        get_circuit_network = function(wire_type, circuit_connector_id)
          return buses[wire_type]
        end,
      }
    end
    return fcpu.get_control_behavior()
  end

  return fcpu
end

function createFCPU_Output(input)
  local ent = table.deep_copy(require('__stdlib__/faketorio/raw/constant-combinator')['constant-combinator'])
  unit_number = unit_number + 1
  ent.unit_number = unit_number
  ent.name = 'output-fcpu'
  ent.valid = true
  ent.get_control_behavior = function()
    if ent._control_behavior == nill or ent._control_behavior.parameters == nil then
      ent._control_behavior = nil
      ent.get_or_create_control_behavior()
    end
    return ent._control_behavior
  end

  ent.get_or_create_control_behavior = function()
    if ent._control_behavior == nil then
      ent._control_behavior = {
        parameters = {},
        signals_count = 100,
      }
      for i = 1, ent._control_behavior.signals_count do
        ent._control_behavior.parameters[i] = {
          signal = {type='virtual', name=''},
          count = 0,
          index = i,
        }
      end

      ent._control_behavior.set_signal = function(index, signal)
        ent._control_behavior.parameters[index] = signal
      end
    end

    return ent.get_control_behavior()
  end

  return ent
end

function ExecuteTest(test_title, program_text, input_signals, probe_result, max_ticks)
  init_globals()

  local fcpu = createFCPU(input_signals)
  local state = Controller.init(fcpu)
  register_fcpu(fcpu, state)

  Controller.verify(state);

  state.program_ics.output = { value = createFCPU_Output() }
  state.program_ics.output.value.get_or_create_control_behavior()

  for i = 1, MC_MEMORY_CHANNELS do
    state.program_ics['mem'..i] = { value = createFCPU_Output() }
  end

  for i = 1, 4 do
    state.program_ics['mem'..i] = { value = createFCPU_Output() }
    state.program_ics['mem'..i].value.get_or_create_control_behavior()
  end

  Controller.update_program_text(state, program_text)
  Controller.compile(state)
  Controller.set_program_counter(state, 1)
  Controller.run(state)

  while state.program_state ~= PSTATE_HALTED do
    if max_ticks ~= nil then
      if 0 < max_ticks then
        max_ticks = max_ticks - 1
      else
        break
      end
    end
    if not Controller.handle(state) then
      break
    end
    World.update()
  end
  if state.error_message then
    error(state.error_message[3])
  end
  if probe_result then
    --local output = fcpu.get_control_behavior().parameters
    local output = state.program_ics.output.value.get_control_behavior().parameters
    local ret = probe_result(state, output, fcpu)
    if ret ~= true and ret ~= nil then
      print(serpent.block(state.regs, {comment=true}))
      print(serpent.block(output, {comment=true}))
      error(ret or ("Test '"..test_title.."' failed"), 2)
    end
  end

  World.quit()

  return fcpu, state
end

----------------------------------------------------------------------------------------------------------------

local fcpu, state = ExecuteTest(
  'Test Subroutines',
  [[
    clr
    mov reg1 1
    jts :test_sub
    jts :test_sub
    hlt

    :test_sub
    inc reg1
    rts
  ]],
  {},
  function (state, output)
    return state.regs[1].count == 3
  end,
  8
)

local fcpu, state = ExecuteTest(
  'Test Stack',
  [[
    clr
    mov reg1 1
    psh reg1
    inc reg1
    psh reg1

    pop reg2
    pop reg3
  ]],
  {},
  function(state, output)
    return state.regs[2].count == 2 and state.regs[3].count == 1
  end,
  8
)

local fcpu, state = ExecuteTest(
  'Bug in fixedpoint',
  [[
    clr
    :loop
    mov reg2 clk
    #mul reg2 0.001
    sin reg1 reg2
    mul reg1 5
    add reg1 5
    jmp :loop
  ]],
  {},
  function(state, output)
    local expected = math.sin(3.0) * 5.0 + 5.0
    return
    (state.regs[1].count == expected)
  end,
  6
)

local fcpu, state = ExecuteTest(
  'check input/output',
  [[
    mov out1 green1
    mov out2 green2
    mov out3 green3
  ]],
  {
    [defines.wire_type.green] = {
      {['item=iron-plate'] = 1000},
      {['item=steel-plate'] = 2000},
      {['item=copper-plate'] = 3000},
    },
    [defines.wire_type.red] = nil,
  },
  function(state, output)
    return Assert.result_signal(output[1], {count=1000, signal={type='item', name='iron-plate'}})
       and Assert.result_signal(output[2], {count=2000, signal={type='item', name='steel-plate'}})
       and Assert.result_signal(output[3], {count=3000, signal={type='item', name='copper-plate'}})
  end
)

local fcpu, state = ExecuteTest(
  'check `crl out`',
  [[
    mov out1 1[item=copper-plate]
    mov out2 2[item=copper-plate]
    mov out3 3[item=copper-plate]
    clr out
  ]],
  {},
  function(state, output)
    return Assert.result_signal(output[1], NULL_SIGNAL)
       and Assert.result_signal(output[2], NULL_SIGNAL)
       and Assert.result_signal(output[3], NULL_SIGNAL)
  end
)


local fcpu, state = ExecuteTest(
  'MOV',
  [[
    mov reg1 10[item=iron-plate]
    mov reg2 green1
    mov reg3 green2
  ]],
  {
    [defines.wire_type.green] = {
      {['item=copper-plate'] = 1000},
      {['item=steel-plate'] = 200},
    },
    [defines.wire_type.red] = nil,
  },
  function(state, output)
    return Assert.result_signal(state.regs[1], {count=10, signal={type='item', name='iron-plate'}})
    and ((state.regs[2].count == 1000 and state.regs[3].count == 200)
      or (state.regs[2].count == 200 and state.regs[3].count == 1000))
  end
)

local fcpu, state = ExecuteTest(
  'Set Signal Value/Type',
  [[
    sst reg1 [item=iron-plate]
    ssv reg1 10
    mov reg2 reg1
    sst reg2 [item=copper-plate]
  ]],
  {},
  function(state, output)
    return Assert.result_signal(state.regs[1], {count=10, signal={type='item', name='iron-plate'}})
    and Assert.result_signal(state.regs[2], {count=10, signal={type='item', name='copper-plate'}})
  end
)

local fcpu, state = ExecuteTest(
  'Set Signal Value/Type (signed)',
  [[
    mov r1 -20.2[item=iron-plate]
  ]],
  {},
  function(state, output)
    return Assert.result_signal(state.regs[1], {count=-20.2, signal={type='item', name='iron-plate'}})
  end
)


local fcpu, state = ExecuteTest(
  'Swap signal/Type/Value',
  [[
    mov reg1 reg2 reg3 reg4 13[item=iron-plate]
    mov reg5 reg6 reg7 reg8 61[item=copper-plate]
    swp reg2 reg6
    swpt reg3 reg7
    swpv reg4 reg8
  ]],
  {},
  function(state, output)
    return
    Assert.result_signal(state.regs[1], {count=13, signal={type='item', name='iron-plate'}}) and
    Assert.result_signal(state.regs[5], {count=61, signal={type='item', name='copper-plate'}}) and

    Assert.result_signal(state.regs[2], {count=61, signal={type='item', name='copper-plate'}}) and
    Assert.result_signal(state.regs[6], {count=13, signal={type='item', name='iron-plate'}}) and

    Assert.result_signal(state.regs[3], {count=13, signal={type='item', name='copper-plate'}}) and
    Assert.result_signal(state.regs[7], {count=61, signal={type='item', name='iron-plate'}}) and

    Assert.result_signal(state.regs[4], {count=61, signal={type='item', name='iron-plate'}}) and
    Assert.result_signal(state.regs[8], {count=13, signal={type='item', name='copper-plate'}})
  end
)


local fcpu, state = ExecuteTest(
  'Find In Red/Green',
  [[
    fig reg1 [item=copper-plate]
    fig reg2 [item=iron-plate]
    fir reg3 [item=steel-plate]
    fir reg4 [item=iron-plate]
  ]],
  {
    [defines.wire_type.green] = {
      {['item=copper-plate'] = 1000},
      {['item=steel-plate'] = 200},
    },
    [defines.wire_type.red] = {
      {['item=copper-plate'] = 40},
      {['item=iron-plate'] = 300},
    },
  },
  function(state, output)
    return Assert.result_signal(state.regs[1], {count=1000, signal={type='item', name='copper-plate'}})
    and Assert.result_signal(state.regs[2], {count=0})
    and Assert.result_signal(state.regs[3], {count=0})
    and Assert.result_signal(state.regs[4], {count=300, signal={type='item', name='iron-plate'}})
  end
)



local fcpu, state = ExecuteTest(
  'Arithmetics',
  [[
    add reg2 2
    # 2
    sub reg2 4
    # -2
    mul reg2 6
    # -12
    div reg2 3
    # -4
    pow reg2 3
    # -64
    mod reg2 -3
    # -1
  ]],
  {},
  function(state, output)
    return (state.regs[2].count == -1)
  end
)


local fcpu, state = ExecuteTest(
  'Digit at Index Get/Set',
  [[
    mov reg3 1234567890
    dig reg3 5
    mov reg4 1234567890
    dis reg4 5 8
    mov reg5 1234567890
    dis reg5 12 8
    mov reg6 1234567890
    dis reg6 1 8
  ]],
  {},
  function(state, output)
    return
    (state.regs[3].count == 6) and
    (state.regs[4].count == 1234587890) and
    (state.regs[5].count == 801234567890) and
    (state.regs[6].count == 1234567898)
  end
)


local fcpu, state = ExecuteTest(
  'Cycle counter',
  [[
    jmp 1
  ]],
  {},
  function(state, output)
    return
    (state.clock == 100)
  end,
  100
)

local fcpu, state = ExecuteTest(
  'Inline comments freeze',
  [[
    mov reg1 1[virtual-signal=signal-X]
    mov reg2 2[virtual-signal=signal-Y]
    mov reg3 3 # one two words, digits: 1 2 3 and some crap: [()[ #
    mov reg4 4
  ]],
  {},
  function(state, output)
    return
    Assert.result_signal(state.regs[1], {count=1, signal={type='virtual', name='signal-X'}}) and
    Assert.result_signal(state.regs[2], {count=2, signal={type='virtual', name='signal-Y'}}) and
    Assert.result_signal(state.regs[3], {count=3}) and
    Assert.result_signal(state.regs[4], {count=4}) and
    (state.clock == 4)
  end,
  5000
)



print(serpent.block(state.regs, {comment=true}))
print("\nAll tests completed successfully")
