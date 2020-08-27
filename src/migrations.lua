local function foreach_fcpu(proc)
  for _, fcpu in pairs(global.fcpus) do
    if fcpu.valid then
      local state = Entity.get_data(fcpu)
      if state then
        proc(fcpu, state)
      end
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
    foreach_fcpu(function(fcpu, state)
      state.instruction_pointer = state.program_counter
      state.program_counter = nil
      Entity.set_data(fcpu, state)
    end)
  end,

  ["0.1.13"] = function()
    foreach_fcpu(function(fcpu, state)
      state.entity = fcpu
      Entity.set_data(fcpu, state)
    end)
  end,

  ["0.2.0"] = function()
    foreach_fcpu(function(fcpu, state)
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
      Controller.compile(state)
      Controller.update_ip(state)
      Controller.update_state(state)
      Entity.set_data(fcpu, state)
      state = fcpu_verify_utility(fcpu)

      if signal then
        control = state.output_fcpu.get_control_behavior()
        local params = control.parameters
        params.parameters[1].signal = signal.signal_id
        params.parameters[1].count = signal.count or 0
        params.parameters[1].index = 1
        control.parameters = params
      end
    end)
  end,

  ["0.2.9"] = function()
    foreach_fcpu(function(fcpu, state)
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
    foreach_player(function(player, player_data)
      if player_data.gui_fcpu then
        player_data.gui_error_message = player_data.gui_fcpu['error_message']
        player_data.gui_editor_toolbar = player_data.gui_fcpu['editor-toolbar']
        set_player_data(player.index, player_data)
      end
    end)
  end,
}
