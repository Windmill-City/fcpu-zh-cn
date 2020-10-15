local Compiler = require('src/cpu/compiler')

Compiler.bind()

PSTATE_HALTED = 0
PSTATE_RUNNING = 1
PSTATE_SLEEPING = 2
PSTATE_BREAKPOINT = 3

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
    program_ics = {},
    ics_stack = {},
    deffered = {},
    breakpoints = {},
    instruction_pointer = 1,
    gui_cache = {}
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

function Controller.verify(state)
  Compiler.verify(state)
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

function Controller.set_error_message(state, err_message)
  if err_message == nil then
    Controller.GuiCache_InvalidateLine(state, state.error_line)
    state.error_line = nil
    state.error_message = nil
  else
    state.error_line = state.instruction_pointer
    state.error_message = {"gui-fcpu.program_error", state.instruction_pointer, err_message}
    Controller.GuiCache_InvalidateLine(state, state.error_line)
    script.raise_event(Controller.event_error, {['entity'] = state.entity, message = state.error_message})
  end
end

function Controller.set_program_counter(state, value)
  Controller.GuiCache_InvalidateLine(state, state.instruction_pointer)
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
  Controller.GuiCache_InvalidateLine(state, state.instruction_pointer)
end

function Controller.do_defferred(state, frames)
  local count = 0
  if state.deffered then
    for k, op in pairs(state.deffered) do
      if op.delay <= frames then
        if op.action == 'disable' then
          if op.ic and op.ic.valid then
            local control = op.ic.get_or_create_control_behavior()
            control.enabled = false
          end
        elseif op.action == 'enable' then
          if op.ic and op.ic.valid then
            local control = op.ic.get_or_create_control_behavior()
            control.enabled = true
          end
        elseif op.action == 'noop' then
        elseif op.action == 'exec' then
          local proc = load('return '..op.proc)
          if proc then
            pcall(proc(), table.unpack(op.args))
          end
        end
        state.deffered[k] = nil
      else
        state.deffered[k].delay = op.delay - frames
      end
      count = count + 1
    end
  end
  return count
end

function Controller.tick(state, sync_wait)
  if state.program_state == PSTATE_BREAKPOINT then
    return
  end

  state.clock = state.clock + 1

  -- Interrupts
  local get_signal = function(signal)
    return state.entity.get_merged_signal(signal.signal, defines.circuit_connector_id.combinator_input) or 0
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
  elseif state.program_state == PSTATE_SLEEPING then
    if 0 < get_signal(HALT_SIGNAL) then
      Controller.halt(state)
    elseif 0 < get_signal(STEP_SIGNAL) then
      if 1 < state.sleep_time then
        state.sleep_time = 0
        Controller.set_program_counter(state, state.instruction_pointer + 1)
        Controller.step(state)
      end
    end
  end
  if true then
    local value = get_signal(JUMP_SIGNAL)
    if 0 < value then
      Controller.set_program_counter(state, value)
    end
  end

::repeat_eval::

  -- Run Controller code.
  if state.program_state == PSTATE_RUNNING and sync_wait < 1 then
    local ast = state.program_ast[state.instruction_pointer]
    local ics = state.program_ics[state.instruction_pointer]
    local success, result = Compiler.eval(ast, ics, state)
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
      elseif result.type == 'block' then
        -- FIXME: should take into account the fcpu_maximum_updates_per_tick limit!
        -- Do nothing, keeping the instruction_pointer the same.
      elseif result.type == 'skip' then
        Controller.set_program_counter(state, state.instruction_pointer + 2)
      elseif result.type == 'next' then
        Controller.set_program_counter(state, state.instruction_pointer + 1)
        goto repeat_eval
      elseif result.type == 'xwait' then
        if sync_wait < 1 then
          Controller.set_program_counter(state, state.instruction_pointer + 1)
        end
      elseif result.type == 'deffer' then
        Controller.set_program_counter(state, state.instruction_pointer + 1)
        for _,v in ipairs(result.deffer) do
          table.insert(state.deffered, v)
        end
        Controller.do_defferred(state, 0)
      end
    else
      Controller.set_program_counter(state, state.instruction_pointer + 1)
      if ast.deffer then
        for _,v in ipairs(ast.deffer) do
          table.insert(state.deffered, table.deep_copy(v))
        end
        Controller.do_defferred(state, 0)
      end
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
  state.do_step = false
  Controller.set_error_message(state, nil)
end

function Controller.step(state)
  if #state.program_ast < state.instruction_pointer then
    Controller.set_program_counter(state, 1)
  end
  Controller.update_state(state, PSTATE_RUNNING)
  state.do_step = true
  Controller.set_error_message(state, nil)
end

function Controller.halt(state)
  Controller.update_state(state, PSTATE_HALTED)
  state.do_step = false
  script.raise_event(Controller.event_halt, {entity = state.entity})
end

function Controller.disable(state, disable)
  state.disabled = (disable == nil or disable)
  if state.disabled then
    Controller.halt(state)
  end
  Controller.update_state(state)
end

function Controller.is_running(state)
  return state.program_state ~= PSTATE_HALTED and state.program_state ~= PSTATE_BREAKPOINT
end

function Controller.is_first_instruction(state)
  return state.program_begin == state.instruction_pointer
end

-------------------------------------------------------------------------------------------------------

function Controller.GuiCache_InvalidateLine(state, line)
  if state.gui_cache then
    if line and state.gui_cache.invalid_lines then
      -- do not add cache until gui initialize it
      state.gui_cache.invalid_lines[line] = true
    else
      -- update all lines
      state.gui_cache.invalid_lines = nil
    end
  end
end

function Controller.update_ip(state)
  --local control = state.entity.get_control_behavior()
  --local param = control.parameters
  --param.parameters.second_constant = state.instruction_pointer
  --control.parameters = param

  -- Stop on next instruction if breakpoint found
  if state.breakpoints[state.instruction_pointer] then
    Controller.halt(state)
    state.program_state = PSTATE_BREAKPOINT
  end
end

function Controller.update_state(state, pstate)
  if state.program_ics.output and state.program_ics.output.valid then
    local control = state.program_ics.output.get_control_behavior()
    control.enabled = not state.disabled
  end

  if state.program_state ~= pstate then
    if pstate ~= nil then
      state.program_state = pstate
    end

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
