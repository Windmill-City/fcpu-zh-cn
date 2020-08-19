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

return {
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
}
