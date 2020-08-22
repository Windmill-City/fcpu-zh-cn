local Compiler = require('src/cpu/compiler')

PSTATE_HALTED = 0
PSTATE_RUNNING = 1
PSTATE_SLEEPING = 2

local pstateStr = {
  [PSTATE_HALTED] = 'signal-fcpu-halt',
  [PSTATE_RUNNING] = 'signal-fcpu-run',
  [PSTATE_SLEEPING] = 'signal-fcpu-sleep',
}

local function linepairs(s)
  if s:sub(-1)~="\n" then s=s.."\n" end
  return s:gmatch("(.-)\n")
end

local Controller = {}

Controller.event_error = script.generate_event_name()
Controller.event_halt = script.generate_event_name()

function Controller.init(mc)
  local state = {
    entity = mc,
    program_text = "",
    program_lines = {},
    program_ast = {},
    program_state = PSTATE_HALTED,
    instruction_pointer = 1
  }

  local control = mc.get_or_create_control_behavior()
  control.parameters = {
    parameters = {
      first_signal = nil,
      second_signal = nil,
      first_constant = nil,
      second_constant = nil,
      operation = "+",
      output_signal = nil
    }
  }
  Controller.init_registers(state)
  return state
end

function Controller.init_registers(state)
  if state.regs == nil then
    state.regs = {}
    for i = 1, MC_REGS do
      state.regs[i] = NULL_SIGNAL
    end
  end
  if not state.clock then
    state.clock = 0
  end
end

function Controller.update_program_text(state, program_text)
  if state.program_text ~= program_text then
    state.program_text = program_text
    return true
  end
end

function Controller.compile(state)
  local program_lines = {}
  for line in linepairs(state.program_text) do
    table.insert(program_lines, line)
  end
  state.program_ast = Compiler.compile(program_lines)
end

function Controller.set_error_message(state, error_message)
  state.error_message = {"gui-fcpu.program_error", state.instruction_pointer, error_message}
  state.error_line = state.instruction_pointer
  script.raise_event(Controller.event_error, {['entity'] = state.entity, ['state'] = state, message = state.error_message})
end

function Controller.set_program_counter(state, value)
  state.instruction_pointer = value
  if #state.program_ast == 0 or state.instruction_pointer > #state.program_ast then
    state.instruction_pointer = 1
    Controller.update_state(state, PSTATE_HALTED)
    state.do_step = false
    script.raise_event(Controller.event_halt, {['entity'] = state.entity, ['state'] = state})
  else
    local next_ast = state.program_ast[state.instruction_pointer]
    while(next_ast and (next_ast.type == 'nop' or next_ast.type == 'label')) do
      state.instruction_pointer = state.instruction_pointer + 1
      if state.instruction_pointer > #state.program_ast then
        break
      end
      next_ast = state.program_ast[state.instruction_pointer]
    end
    if state.instruction_pointer > #state.program_ast then
      Controller.update_state(state, PSTATE_HALTED)
      state.do_step = false
      script.raise_event(Controller.event_halt, {['entity'] = state.entity, ['state'] = state})
    end
  end
  Controller.update_ip(state)
end

function Controller.tick(state)
  state.clock = state.clock + 1

  -- Interrupts
  local control = state.entity.get_control_behavior()
  local red_input = control.get_circuit_network(defines.wire_type.red, defines.circuit_connector_id.combinator_input)
  local green_input = control.get_circuit_network(defines.wire_type.green, defines.circuit_connector_id.combinator_input)
  local get_signal = function(signal)
    local result = 0
    if red_input then
      local r = red_input.get_signal(signal.signal)
      result = result + r
    end
    if green_input then
      local g = green_input.get_signal(signal.signal)
      result = result + g
    end
    return result
  end
  if state.program_state == PSTATE_RUNNING and 0 < get_signal(HALT_SIGNAL) then
    Controller.halt(state)
  end
  if state.program_state == PSTATE_HALTED and 0 < get_signal(RUN_SIGNAL) then
    Controller.run(state)
  end
  if state.program_state == PSTATE_HALTED and 0 < get_signal(STEP_SIGNAL) then
    Controller.step(state)
  end
  if state.program_state == PSTATE_RUNNING then
    local value = get_signal(SLEEP_SIGNAL)
    if 0 < value then
      Controller.update_state(state, PSTATE_SLEEPING)
      state.sleep_time = value
    end
  end
  if true then
    local value = get_signal(JUMP_SIGNAL)
    if 0 < value then
      Controller.set_program_counter(state, value)
    end
  end

  -- Run Controller code.
  if state.program_state == PSTATE_RUNNING then
    local ast = state.program_ast[state.instruction_pointer]
    local success, result = Compiler.eval(ast, control, state)
    if not success then
      Controller.set_error_message(state, result)
      Controller.halt(state)
    elseif result then
      if result.type == 'halt' then
        Controller.halt(state)
        Controller.set_program_counter(state, state.instruction_pointer + 1)
      elseif result.type == 'sleep' then
        Controller.update_state(state, PSTATE_SLEEPING)
        state.sleep_time = result.val
      elseif result.type == 'jump' then
        if result.label then
          for line_num, node in ipairs(state.program_ast) do
            if node.type == 'label' and node.label == result.label then
              Controller.set_program_counter(state, line_num + 1)
              break
            end
          end
        else
          Controller.set_program_counter(state, result.val)
        end
      elseif result.type == 'skip' then
        Controller.set_program_counter(state, state.instruction_pointer + 2)
      elseif result.type == 'block' then
        -- FIXME: should take into account the fcpu_maximum_updates_per_tick limit!
        -- Do nothing, keeping the instruction_pointer the same.
      end
    else
      Controller.set_program_counter(state, state.instruction_pointer + 1)
    end
  elseif state.program_state == PSTATE_SLEEPING then
    state.sleep_time = state.sleep_time - 1
    if state.sleep_time <= 1 then
      Controller.update_state(state, PSTATE_RUNNING)
      Controller.set_program_counter(state, state.instruction_pointer + 1)
    end
  end

  if state.do_step and state.program_state == PSTATE_RUNNING then
    state.do_step = false
    Controller.halt(state)
  end
end

function Controller.run(state)
  Controller.update_state(state, PSTATE_RUNNING)
  state.error_message = nil
  state.error_line = nil
  state.do_step = false
end

function Controller.step(state)
  if state.instruction_pointer > #state.program_ast then
    Controller.set_program_counter(state, 1)
  end
  Controller.update_state(state, PSTATE_RUNNING)
  state.do_step = true
  state.error_message = nil
  state.error_line = nil
end

function Controller.halt(state)
  if state.program_state == PSTATE_HALTED then
    Controller.set_program_counter(state, 1)
  end
  Controller.update_state(state, PSTATE_HALTED)
  state.do_step = false
  script.raise_event(Controller.event_halt, {entity = state.entity, ['state'] = state})
end

function Controller.is_running(state)
  return state.program_state ~= PSTATE_HALTED
end

-------------------------------------------------------------------------------------------------------

function Controller.update_ip(state)
  --local control = state.entity.get_control_behavior()
  --local param = control.parameters
  --param.parameters.second_constant = state.instruction_pointer
  --control.parameters = param
end

function Controller.update_state(state, pstate)
  if state.output_fcpu then
    local control = state.output_fcpu.get_control_behavior()
    control.enabled = not state.disabled
  end

  if state.program_state ~= pstate then
    if pstate ~= nil then
      state.program_state = pstate
    end

    local str = pstateStr[state.program_state]
    if state.error_message and state.program_state == PSTATE_HALTED then
      str = 'signal-fcpu-error'
    end
    if str then
      local control = state.entity.get_control_behavior()
      local param = control.parameters
      param.parameters.first_signal = { type="virtual", name=str }
      control.parameters = param
    end
  end
end

return Controller
