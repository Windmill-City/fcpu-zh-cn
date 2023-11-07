Assert = require('src/cpu/assert')
local Compiler = require('src/cpu/compiler')
local Evaluator = require('src/cpu/evaluator')

PSTATE_HALTED = 0
PSTATE_RUNNING = 1
PSTATE_SLEEPING = 2
PSTATE_BREAKPOINT = 3

local pstateStr = {
  [PSTATE_HALTED] = 'signal-fcpu-halt',
  [PSTATE_RUNNING] = 'signal-fcpu-run',
  [PSTATE_SLEEPING] = 'signal-fcpu-sleep',
}

local Controller = {}

Controller.event_error = script.generate_event_name()
Controller.event_halt = script.generate_event_name()

function Controller.init(mc)
  local control = mc.get_or_create_control_behavior()
  control.parameters = {
    first_signal = nil,
    second_signal = nil,
    first_constant = nil,
    second_constant = nil,
    operation = "+",
    output_signal = nil
  }
  local state = {
    entity = mc,
    program_text = "",
    program_lines = {},
    program_ast = {},
    program_state = PSTATE_HALTED,
    program_begin = 1,
    program_ics = {},
    ics_stack = {},
    breakpoints = {},
    instruction_pointer = 1,
    gui_cache = {},
    cache = {
      control = {
        indication = control
      },
      wires = {},
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
    state.program_ast = Compiler.compile(state.program_text)
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
  if length == 0 or length < value or value < 1 then
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

local function advance(state, inc)
  Controller.set_program_counter(state, state.instruction_pointer + (inc or 1))
end

local function run_deffer_command(op)
  debug_assert(not op.at or op.at + op.delay == game.tick, "Out of order deffered action executed")

  if op.action == 'wake' then
    local state = global.fcpus[op.index]
    if state and state.sleep_at == op.at then
      debug_assert(state.sleep_at + op.delay == game.tick)
      state.clock = state.clock + state.sleep_time
      state.sleep_time = 0
      Controller.update_state(state, PSTATE_RUNNING)
      advance(state)
    end
  elseif op.action == 'sync' then
    Assert.check(op.index ~= nil, 'fCPU instance index is nil in SYNC')
    local state = global.fcpus[op.index]
    if state then
      state.need_sync = nil
      state.clock = state.clock + op.delay
      advance(state)
    end
  elseif op.action == 'disable' then
    if op.ic and op.ic.valid then
      local control = op.ic.get_or_create_control_behavior()
      control.enabled = false
    end
  elseif op.action == 'enable' then
    if op.ic and op.ic.valid then
      local control = op.ic.get_or_create_control_behavior()
      control.enabled = true
    end
  elseif op.action == 'tune' then
    if op.ic and op.ic.valid then
      local control = op.ic.get_or_create_control_behavior()
      local params = control.parameters
      params.constant = op.value
      control.parameters = params
    end
  elseif op.action == 'exec' then
    local proc = load('return '..op.proc)
    if proc then
      pcall(proc(), table.unpack(op.args))
    end
  end
end

function Controller.add_deferred(state, deffer)
  local will_sync = false
  --local got_sync = false
  --local cnt = #deffer
  -- only numeric indices, skip named one!
  for i, op in ipairs(deffer) do
    if op.delay == 0 then
      run_deffer_command(op)
    else
      local t = table.deep_copy(op)
      local at_tick = game.tick + t.delay
      t.at = game.tick
      Heap.put(global.deffered, at_tick, t)
      will_sync = will_sync or (t.action == 'sync')
    end
    --got_sync = got_sync or op.action == 'sync' or not got_sync and i == cnt
  end
  state.need_sync = will_sync-- or not got_sync
  return will_sync
end

function Controller.do_defferred()
  while true do
    local p = Heap.priority(global.deffered)
    if not p or game.tick < p then
      break
    end
    local at_tick, op = Heap.pop(global.deffered)
    assert(at_tick == game.tick, "Found missed deffered action")
    run_deffer_command(op)
  end
end

function Controller.validate_cache(state)
  local cache = state.cache

  -- Cache.Control
  local control = cache.control

  if not (control.output and control.output.valid) then
    if state.program_ics.output.value and state.program_ics.output.value.valid then
      control.output = state.program_ics.output.value.get_control_behavior()
    end
  end

  -- should be always valid
  if not (control.indication and control.indication.valid) then
    control.indication = state.entity.get_control_behavior()
  end

  -- Cache.Wires
  local wires = cache.wires

  if not (wires.red and wires.red.valid) then
    wires.red = control.indication.get_circuit_network(defines.wire_type.red, defines.circuit_connector_id.combinator_input)
  end

  if not (wires.green and wires.green.valid) then
    wires.green = control.indication.get_circuit_network(defines.wire_type.green, defines.circuit_connector_id.combinator_input)
  end
end

function Controller.handle_interrupts(state)
  local get_signal = function(signal)
    local t = state.entity.get_merged_signal(signal.signal, defines.circuit_connector_id.combinator_input)
    return t or 0
  end
  if state.program_state == PSTATE_RUNNING then
    if 0 < get_signal(HALT_SIGNAL) then
      Controller.halt(state)
    else
      local value = get_signal(SLEEP_SIGNAL)
      if value ~= 0 then
        Controller.sleep(state, value)
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
end

function Controller.tick(state, sync_wait)
  if state.program_state == PSTATE_BREAKPOINT then
    return
  end

  Controller.validate_cache(state)
  Controller.handle_interrupts(state)

  -- Run Controller code.
  if state.program_state == PSTATE_RUNNING then
    if not sync_wait then
      state.clock = state.clock + 1

      ::repeat_eval::

      local ast = state.program_ast[state.instruction_pointer]
      local ics = state.program_ics[state.instruction_pointer]
      local success, result = Evaluator.eval(ast, ics, state)
      if not success then
        Controller.set_error_message(state, result)
        Controller.halt(state)
      elseif result then
        if result.type == 'halt' then
          Controller.halt(state)
          advance(state)
        elseif result.type == 'sleep' then
          Controller.sleep(state, result.val)
        elseif result.type == 'jump' then
          if result.label then
            for line_num, node in ipairs(state.program_ast) do
              if node.type == 'label' and node.label == result.label then
                Controller.set_program_counter(state, line_num + 1 + (result.val or 0))
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
          advance(state, 2)
        elseif result.type == 'next' then
          advance(state)
          if (state.program_state ~= PSTATE_HALTED) then
            goto repeat_eval
          end
        elseif result.type == 'xwait' then
          if not sync_wait then
            advance(state)
          end
        elseif result.type == 'deffer' then
          if not Controller.add_deferred(state, result.deffer) then
            advance(state)
          end
        end
      else
        if ast and ast.deffer then
          if not Controller.add_deferred(state, ast.deffer.run) then
            advance(state)
          end
        else
          advance(state)
        end
      end
    end

    if state.do_step and state.program_state == PSTATE_RUNNING then
      Controller.halt(state)
    end
  elseif state.program_state == PSTATE_SLEEPING then
    global.running[state.index] = nil
  end
end

function Controller.run(state)
  Controller.set_error_message(state, nil)
  state.sleep_time = 0
  state.need_sync = nil
  state.do_step = false
  Controller.update_state(state, PSTATE_RUNNING)
end

function Controller.step(state, over)
  Controller.set_error_message(state, nil)
  if state.program_state == PSTATE_SLEEPING then
    advance(state)
    Controller.halt(state)
  else
    state.sleep_time = 0
    state.need_sync = nil
    state.do_step = true
    Controller.update_state(state, PSTATE_RUNNING)
  end
  if #state.program_ast < state.instruction_pointer then
    Controller.set_program_counter(state, 1)
  end
end

function Controller.sleep(state, value)
  if 0 < value then
    debug_assert(state.sleep_time == 0)
    state.sleep_time = math.floor(value)
  else
    state.sleep_time = 0
  end
  Controller.update_state(state, PSTATE_SLEEPING)
end

function Controller.halt(state, reset)
  if reset then
    Controller.set_program_counter(state, 1)
    Evaluator.eval({ type='op', name='clr' }, nil, state)
  end
  state.sleep_at = nil
  state.sleep_time = 0
  state.need_sync = nil
  state.do_step = false
  Controller.update_state(state, PSTATE_HALTED)
  script.raise_event(Controller.event_halt, {entity = state.entity})
end

function Controller.disable(state, disable)
  state.disabled = (disable ~= false)
  if state.disabled then
    Controller.halt(state)
  else
    Controller.update_state(state)
  end
end

function Controller.is_running(state)
  return state.program_state ~= PSTATE_HALTED and state.program_state ~= PSTATE_BREAKPOINT
end

function Controller.is_sleeping(state)
  return state.program_state == PSTATE_SLEEPING
end

function Controller.is_error(state)
  return state.program_state == PSTATE_HALTED and state.error_line ~= nil
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
  --local control = state.cache.control.indication
  --local param = control.parameters
  --param.second_constant = state.instruction_pointer
  --control.parameters = param

  -- Stop on next instruction if breakpoint found
  if state.breakpoints[state.instruction_pointer] then
    Controller.halt(state)
    state.program_state = PSTATE_BREAKPOINT
  end
end

function Controller.update_state(state, pstate)
  local control = state.cache.control

  if state.program_state ~= pstate then
    if pstate ~= nil then
      state.program_state = pstate
      if pstate == PSTATE_RUNNING then
        global.running[state.index] = state.index
        state.sleep_at = nil
      elseif pstate == PSTATE_SLEEPING and state.sleep_time then
        global.running[state.index] = nil
        state.sleep_at = game.tick
        Controller.add_deferred(state, {{action='wake', at=state.sleep_at, delay=state.sleep_time, index=state.index}})
      else
        if pstate == PSTATE_HALTED then
          state.sleep_at = nil
        end
        if state.disabled then
          global.running[state.index] = nil
        end
      end
    end

    if control then
      local indication_ctrl = control.indication -- should be always valid
      if indication_ctrl and indication_ctrl.valid then
        local str = pstateStr[state.program_state]
        local params = indication_ctrl.parameters
        if state.disabled then
          params.first_constant = nil
          params.first_signal = nil
          params.output_signal = nil
        elseif state.error_message and state.program_state == PSTATE_HALTED then
          params.first_constant = state.instruction_pointer
          params.first_signal = nil
          params.output_signal = { type="virtual", name='signal-fcpu-error' }
        elseif str then
          params.first_constant = nil
          params.first_signal = { type="virtual", name=str }
          params.output_signal = nil
        end
        indication_ctrl.parameters = params
      end
    end
  end

  if control then
    local output_ctrl = control.output
    if output_ctrl and output_ctrl.valid then
      output_ctrl.enabled = not state.disabled
    end
  end
end


Compiler.setup(Evaluator, Controller)

return Controller
