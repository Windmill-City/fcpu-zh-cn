local Compiler = require('compiler')

--require('src/constants')
PSTATE_HALTED = 0
PSTATE_RUNNING = 1
PSTATE_SLEEPING = 2
-- {
NULL_SIGNAL = {signal = { type = "virtual", name = "signal-black" }, count = 0}
HALT_SIGNAL = {signal = { type = "virtual", name = "signal-fcpu-halt"}, count = 1}
RUN_SIGNAL = {signal = { type = "virtual", name = "signal-fcpu-run"}, count = 1}
STEP_SIGNAL = {signal = { type = "virtual", name = "signal-fcpu-step"}, count = 1}
SLEEP_SIGNAL = {signal = { type = "virtual", name = "signal-fcpu-sleep"}, count = 1}
JUMP_SIGNAL = {signal = { type = "virtual", name = "signal-fcpu-jump"}, count = 1}
-- }

function linepairs(s)
  if s:sub(-1)~="\n" then s=s.."\n" end
  return s:gmatch("(.-)\n")
end

local Controller = {}

Controller.event_error = script.generate_event_name()
Controller.event_halt = script.generate_event_name()

function Controller.init(mc, state)
  state.program_lines = {}
  state.program_text = ""
  state.program_counter = 1
  state.program_ast = {}
  state.program_state = PSTATE_HALTED
  Entity.set_data(mc, state)

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
  Controller.init_memory(mc, state)
  return state
end

function Controller.init_memory(mc, state)
  if state.memory == nil then
    state.memory = {}
    for i = 1, 4 do
      state.memory[i] = NULL_SIGNAL
    end
  end
  if not state.clock then
    state.clock = 1
  end
end

function Controller.update_program_text(mc, program_text)
  local state = Entity.get_data(mc)
  state.program_text = program_text
  Entity.set_data(mc, state)
end

function Controller.compile(mc, state)
  local program_lines = {}
  for line in linepairs(state.program_text) do
    table.insert(program_lines, line)
  end
  state.program_ast = Compiler.compile(program_lines)
  Entity.set_data(mc, state)
end

function Controller.set_error_message(mc, state, error_message)
  state.error_message = {"gui-fcpu.program_error", state.program_counter, error_message}
  state.error_line = state.program_counter
  script.raise_event(Controller.event_error, {entity = mc, ['state'] = state, message = state.error_message})
end

function Controller.set_program_counter(mc, state, value)
  state.program_counter = value
  if #state.program_ast == 0 or state.program_counter > #state.program_ast then
    state.program_counter = 1
    state.program_state = PSTATE_HALTED
    state.do_step = false
    script.raise_event(Controller.event_halt, {entity = mc, ['state'] = state})
  else
    local next_ast = state.program_ast[state.program_counter]
    while(next_ast and (next_ast.type == 'nop' or next_ast.type == 'label')) do
      state.program_counter = state.program_counter + 1
      if state.program_counter > #state.program_ast then
        break
      end
      next_ast = state.program_ast[state.program_counter]
    end
    if state.program_counter > #state.program_ast then
      state.program_state = PSTATE_HALTED
      state.do_step = false
      script.raise_event(Controller.event_halt, {entity = mc, ['state'] = state})
    end
  end
end

function Controller.tick(mc, state)
  Controller.init_memory(mc, state)
  state.clock = state.clock + 1

  -- Interrupts
  local control = mc.get_control_behavior()
  local red_input = control.get_circuit_network(defines.wire_type.red, defines.circuit_connector_id.combinator_input)
  local green_input = control.get_circuit_network(defines.wire_type.green, defines.circuit_connector_id.combinator_input)
  local get_signal = function(signal)
    if red_input then
      local result = red_input.get_signal(signal.signal)
      if result ~= nil then
        return result
      end
    end
    if green_input then
      local result = green_input.get_signal(signal.signal)
      if result ~= nil then
        return result
      end
    end
    return 0
  end
  if state.program_state == PSTATE_RUNNING and get_signal(HALT_SIGNAL) > 0 then
    Controller.halt(mc, state)
  end
  if state.program_state == PSTATE_HALTED and get_signal(RUN_SIGNAL) > 0 then
    Controller.run(mc, state, state.program_counter)
  end
  if state.program_state == PSTATE_HALTED and get_signal(STEP_SIGNAL) > 0 then
    Controller.step(mc, state)
  end
  if state.program_state == PSTATE_RUNNING and get_signal(SLEEP_SIGNAL) > 0 then
    local value = get_signal(SLEEP_SIGNAL)
    if value then
      state.program_state = PSTATE_SLEEPING
      state.sleep_time = value
    end
  end
  if get_signal(JUMP_SIGNAL) > 0 then
    local value = get_signal(JUMP_SIGNAL)
    if value then
      Controller.set_program_counter(mc, state, value)
    end
  end

  -- Run Controller code.
  if state.program_state == PSTATE_RUNNING then
    local ast = state.program_ast[state.program_counter]
    local success, result = Compiler.eval(ast, control, state)
    if not success then
      Controller.set_error_message(mc, state, result)
      Controller.halt(mc, state)
    elseif result then
      if result.type == 'halt' then
        Controller.halt(mc, state)
        Controller.set_program_counter(mc, state, state.program_counter + 1)
      elseif result.type == 'sleep' then
        state.program_state = PSTATE_SLEEPING
        state.sleep_time = result.val
      elseif result.type == 'jump' then
        if result.label then
          for line_num, node in ipairs(state.program_ast) do
            if node.type == 'label' and node.label == result.label then
              Controller.set_program_counter(mc, state, line_num + 1)
              break
            end
          end
        else
          Controller.set_program_counter(mc, state, result.val)
        end
      elseif result.type == 'skip' then
        Controller.set_program_counter(mc, state, state.program_counter + 2)
      elseif result.type == 'block' then
        -- FIXME: should take into account the fcpu_maximum_updates_per_tick limit!
        -- Do nothing, keeping the program_counter the same.
      end
    else
      Controller.set_program_counter(mc, state, state.program_counter + 1)
    end
  elseif state.program_state == PSTATE_SLEEPING then
    state.sleep_time = state.sleep_time - 1
    if state.sleep_time <= 1 then
      state.program_state = PSTATE_RUNNING
      Controller.set_program_counter(mc, state, state.program_counter + 1)
    end
  end

  if state.do_step and state.program_state == PSTATE_RUNNING then
    state.do_step = false
    Controller.halt(mc, state)
  end

  Entity.set_data(mc, state)
end

function Controller.run(mc, state)
  state.program_state = PSTATE_RUNNING
  state.error_message = nil
  state.error_line = nil
  state.do_step = false
  Entity.set_data(mc, state)
end

function Controller.step(mc, state)
  if state.program_counter > #state.program_ast then
    Controller.set_program_counter(mc, state, 1)
  end
  state.program_state = PSTATE_RUNNING
  state.do_step = true
  state.error_message = nil
  state.error_line = nil
  Entity.set_data(mc, state)
end

function Controller.halt(mc, state)
  if state.program_state == PSTATE_HALTED then
    Controller.set_program_counter(mc, state, 1)
  end
  state.program_state = PSTATE_HALTED
  state.do_step = false
  Entity.set_data(mc, state)
  script.raise_event(Controller.event_halt, {entity = mc, ['state'] = state})
end

function Controller.is_running(mc)
  return Entity.get_data(mc).program_state ~= PSTATE_HALTED
end

return Controller