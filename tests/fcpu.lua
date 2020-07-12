local World = require('__stdlib__/faketorio/world')
World.bootstrap()


Entity = require('__stdlib__/stdlib/entity/entity')
table = require('__stdlib__/stdlib/utils/table')

require('../src/constants')
Controller = require('../src/controller')

----------------------------------------------------------------------------------------------------------------

unit_number = 0

function createFCPU(input)
  local fcpu = table.deepcopy(require('__stdlib__/faketorio/raw/arithmetic-combinator')['arithmetic-combinator'])
  unit_number = unit_number + 1
  fcpu.unit_number = unit_number
  fcpu.name = 'fcpu'
  fcpu.get_control_behavior = function()
    return fcpu._control_behavior
  end

  local MakeBus = function(bus)
    local out = {
      signals = {},
      get_signal = function(signal)
        return bus and bus[signal.name] or nil
      end
    }
    if bus then
      for k,v in pairs(bus) do
        local t, n = string.match(k, '(%a+)-([%a%-]+)')
        table.insert(out.signals, { signal = { type = t, name = n }, count = v })
      end
    end
    return out
  end
  local buses = {
    [defines.wire_type.green] = MakeBus(input[defines.wire_type.green]),
    [defines.wire_type.red] = MakeBus(input[defines.wire_type.red]),
  }

  fcpu.get_or_create_control_behavior = function()
    if fcpu._control_behavior == nil then
      fcpu._control_behavior = {
        parameters = {},
        get_circuit_network = function(wire_type, circuit_connector_id)
          return buses[wire_type]
        end,
      }
    end
    return fcpu.get_control_behavior()
  end
  return fcpu
end

function executeTest(test_title, program_text, input_signals, probe_result, max_ticks)
  local fcpu = createFCPU(input_signals)
  local state = Controller.init(fcpu, {})
  
  Controller.update_program_text(fcpu, program_text)
  
  Controller.compile(fcpu, state)
  Controller.set_program_counter(fcpu, state, 1)
  Controller.run(fcpu, state)
  
  while state.program_state ~= PSTATE_HALTED do
    Controller.tick(fcpu, state)
    if max_ticks then
      if 0 < max_ticks then
        max_ticks = max_ticks - 1
      else
        break
      end
    end
  end
  if state.error_message then
    error(state.error_message[3])
  end
  if probe_result then
    local output = fcpu.get_control_behavior().parameters.parameters
    local ret = probe_result(state, output)
    if ret ~= true and ret ~= nil then
      print(serpent.block(state.regs, {comment=true}))
      print(serpent.block(output, {comment=true}))
      error(ret or ("Test '"..test_title.."' failed"), 2)
    end
  end
  return fcpu, state
end

----------------------------------------------------------------------------------------------------------------

local fcpu, state = executeTest(
  'MOV',
  [[
    mov reg1 10[recipe-iron-plate]
    mov reg2 green1
    mov reg3 green2
  ]],
  {
    [defines.wire_type.green] = {
      ['recipe-copper-plate'] = 1000,
      ['recipe-steel-plate'] = 200,
    },
    [defines.wire_type.red] = nil,
  },
  function(state, output)
    return (state.regs[1].count == 10 and state.regs[1].signal.type == 'recipe' and state.regs[1].signal.name == 'iron-plate')
    and ((state.regs[2].count == 1000 and state.regs[3].count == 200)
      or (state.regs[2].count == 200 and state.regs[3].count == 1000))
  end
)


local fcpu, state = executeTest(
  'check output',
  [[
    mov out green1
  ]],
  {
    [defines.wire_type.green] = {
      ['recipe-copper-plate'] = 1000,
    },
    [defines.wire_type.red] = nil,
  },
  function(state, output)
    return output.output_signal.type == 'recipe' and output.output_signal.name == 'copper-plate' and output.first_constant == 1000
  end
)


local fcpu, state = executeTest(
  'Arithmetics',
  [[
    add reg2 2
    sub reg2 4
    mul reg2 6
    div reg2 3
  ]],
  {},
  function(state, output)
    return state.regs[2].count == -4
  end
)

print(serpent.block(state.regs, {comment=true}))
print("\nAll tests completed successfully")
