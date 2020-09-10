local Compiler = require('src/cpu/compiler')

Compiler.bind()

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
    program_begin = 1,
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
    state.modified = true
    return true
  end
end

local function SkipNOPs(ast, i, limit)
  local length = #ast
  local hops = limit or length
  local next = ast[i]
  while (next and (next.type == 'nop' and next.name == 'comment' or next.type == 'label')) do
    i = i % length + 1
    hops = hops - 1
    if hops < 1 then
      return false
    end
    next = ast[i]
  end
  return i
end

function Controller.compile(state)
  if state.modified or not (state.program_ast and 0 < #state.program_ast) then
    local program_lines = {}
    for line in linepairs(state.program_text) do
      table.insert(program_lines, line)
    end

    state.program_ast = Compiler.compile(program_lines)
    state.program_begin = SkipNOPs(state.program_ast, 1) or 1
    state.ics_stack = {}
  end

  Compiler.build(state, state.modified)

  state.modified = false
end

function Controller.set_error_message(state, error_message)
  state.error_message = {"gui-fcpu.program_error", state.instruction_pointer, error_message}
  state.error_line = state.instruction_pointer
  script.raise_event(Controller.event_error, {['entity'] = state.entity, message = state.error_message})
end

function Controller.set_program_counter(state, value)
  local length = #state.program_ast
  if length == 0 or length < value then
    state.instruction_pointer = state.program_begin or 1
    Controller.update_state(state, PSTATE_HALTED)
    state.do_step = false
    script.raise_event(Controller.event_halt, {['entity'] = state.entity})
  else
    local i = SkipNOPs(state.program_ast, value, length - value + 1)
    if i == false then
      state.instruction_pointer = state.program_begin or 1
      Controller.update_state(state, PSTATE_HALTED)
      state.do_step = false
      script.raise_event(Controller.event_halt, {['entity'] = state.entity})
    else
      state.instruction_pointer = i
    end
  end
  Controller.update_ip(state)
end

function Controller.do_defferred(state)
  for k, v in pairs(state.deffer) do
    if v.delay <= 1 and v.ops then
      for _, op in ipairs(v.ops) do
        if op.action == 'disable' then
          if op.ic and op.ic.valid then
            local control = op.ic.get_or_create_control_behavior()
            control.enabled = false
          end
        end
      end
      state.deffer[k] = nil
    else
      state.deffer[k].delay = v.delay - 1
    end
  end
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
  if state.program_state == PSTATE_RUNNING then
    if 0 < get_signal(HALT_SIGNAL) then
      Controller.halt(state)
    else
      local value = get_signal(SLEEP_SIGNAL)
      if 0 < value then
        Controller.update_state(state, PSTATE_SLEEPING)
        state.sleep_time = value
      end
    end
  elseif state.program_state == PSTATE_HALTED then
    if 0 < get_signal(RUN_SIGNAL) then
      Controller.run(state)
    elseif 0 < get_signal(STEP_SIGNAL) then
      Controller.step(state)
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
    local ics = state.program_ics[state.instruction_pointer]
    local success, result = Compiler.eval(ast, ics, control, state)
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
      elseif result.type == 'deffer' then
        Controller.set_program_counter(state, state.instruction_pointer + 1)
        result.type = nil
        state.deffer = state.deffer or {}
        table.insert(state.deffer, result)
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
  if #state.program_ast < state.instruction_pointer then
    Controller.set_program_counter(state, 1)
  end
  Controller.update_state(state, PSTATE_RUNNING)
  state.do_step = true
  state.error_message = nil
  state.error_line = nil
end

function Controller.halt(state)
  Controller.update_state(state, PSTATE_HALTED)
  state.do_step = false
  script.raise_event(Controller.event_halt, {entity = state.entity})
end

function Controller.is_running(state)
  return state.program_state ~= PSTATE_HALTED
end

function Controller.is_first_instruction(state)
  return state.program_begin == state.instruction_pointer
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

    fcpu_update_blueprint(state.entity)

    local str = pstateStr[state.program_state]
    local control = state.entity.get_control_behavior()
    local param = control.parameters
    if state.disabled then
      param.parameters.first_constant = nil
      param.parameters.first_signal = nil
      param.parameters.output_signal = nil
    elseif state.error_message and state.program_state == PSTATE_HALTED then
      param.parameters.first_constant = state.instruction_pointer
      param.parameters.first_signal = nil
      param.parameters.output_signal = { type="virtual", name='signal-fcpu-error' }
    elseif str then
      param.parameters.first_constant = nil
      param.parameters.first_signal = { type="virtual", name=str }
      param.parameters.output_signal = nil
    end
    control.parameters = param
  end
end

return Controller
