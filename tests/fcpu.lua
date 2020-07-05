local World = require('__stdlib__/faketorio/world')
World.bootstrap()


Entity = require('__stdlib__/stdlib/entity/entity')
table = require('__stdlib__/stdlib/utils/table')

require('../src/constants')
Controller = require('../src/controller')

----------------------------------------------------------------------------------------------------------------

function createFCPU(input)
  local fcpu = require('__stdlib__/faketorio/raw/arithmetic-combinator')['arithmetic-combinator']
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
        table.insert(out.signals, { signal = k, count = v })
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

function executeTest(inputSignals, program_text, max_ticks)
  local fcpu = createFCPU(inputSignals)
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
  return fcpu, state
end

----------------------------------------------------------------------------------------------------------------

local fcpu, state = executeTest(
  {
    [defines.wire_type.green] = {
      ['signal-white'] = 10,
      ['recipe-copper-plate'] = 1000
    },
    [defines.wire_type.red] = nil
  },
  [[
    mov green1 out
    mov green2 out
  ]]
)

--print(serpent.block(state.memory))
print(serpent.block(fcpu.get_control_behavior().parameters.parameters))
