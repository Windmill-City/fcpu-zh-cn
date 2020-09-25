local function foreach_fcpu_v1(proc)
  for _, fcpu in pairs(global.fcpus) do
    if fcpu.valid then
      local state = Entity.get_data(fcpu)
      if state then
        proc(fcpu, state)
      end
    end
  end
end

local function foreach_fcpu(proc)
  for k, state in pairs(global.fcpus) do
    if state and state.entity and state.entity.valid then
      proc(state.entity, state)
    else
      global.fcpus[k] = nil
    end
  end
end

local function foreach_player(proc)
  for _, player in pairs(game.players) do
    local player_data = get_player_data(player.index)
    if player_data then
      proc(player, player_data)
    end
  end
end

return {
  ["0.0.1"] = function()
    foreach_fcpu_v1(function(fcpu, state)
      state.instruction_pointer = state.program_counter
      state.program_counter = nil
      Entity.set_data(fcpu, state)
    end)
  end,

  ["0.1.13"] = function()
    foreach_fcpu_v1(function(fcpu, state)
      state.entity = fcpu
      Entity.set_data(fcpu, state)
    end)
  end,

  ["0.2.0"] = function()
    foreach_fcpu_v1(function(fcpu, state)
      local signal
      local control = fcpu.get_or_create_control_behavior()
      if control then
        signal = {
          count = control.parameters.parameters.first_constant,
          signal_id = control.parameters.parameters.output_signal
        }
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
      end
      state.program_ics = {}
      Controller.verify(state)
      Controller.compile(state)
      Controller.update_ip(state)
      Controller.update_state(state)
      Entity.set_data(fcpu, state)

      if signal then
        control = state.program_ics.output.get_control_behavior()
        local params = control.parameters
        params.parameters[1].signal = signal.signal_id
        params.parameters[1].count = signal.count or 0
        params.parameters[1].index = 1
        control.parameters = params
      end
    end)
  end,

  ["0.2.9"] = function()
    foreach_fcpu_v1(function(fcpu, state)
      state.gui_fcpu = nil
      state.gui_exit_button = nil
      state.gui_halt_button = nil
      state.gui_step_button = nil
      state.gui_run_button = nil
      state.gui_enable_switch = nil
      state.gui_inspector = nil
      state.gui_line_numbers = nil
      state.gui_program_input = nil
      Entity.set_data(fcpu, state)
    end)
  end,

  ["0.3.0"] = function()
    local fcpus = {}
    for _,v in pairs(global.fcpus) do
      local state = Entity.get_data(v)
      state.destroy_regnum = script.register_on_entity_destroyed(v)
      state.index = #fcpus + 1
      fcpus[state.index] = state
      Entity.set_data(state.entity, state.index)
    end
    global.fcpus = fcpus

    foreach_fcpu(function(fcpu, state)
      state.program_begin = 1
      state.program_ics = state.program_ics or {}
      state.ics_stack = {}
      state.deffered = {}
      state.program_ics.output = state.program_ics.output or state.output_fcpu
      state.output_fcpu = nil

      if state.imposter_fcpu then
        if state.imposter_fcpu.valid then
          Entity.set_data(state.imposter_fcpu, nil)
          state.imposter_fcpu.destroy()
        end
        state.imposter_fcpu = nil
      end
    end)
    foreach_player(function(player, player_data)
      if player_data.gui_fcpu then
        player_data.gui_error_message = player_data.gui_fcpu['error_message']
        player_data.gui_editor_toolbar = player_data.gui_fcpu['editor-toolbar']
        set_player_data(player.index, player_data)
      end
    end)
    for _, surface in pairs(game.surfaces) do
      for _, imposter_fcpu in pairs(surface.find_entities_filtered{ name="imposter-fcpu" }) do
        if imposter_fcpu then
          if imposter_fcpu.valid then
            Entity.set_data(imposter_fcpu, nil)
            imposter_fcpu.destroy()
          end
        end
      end
    end
  end,
}
