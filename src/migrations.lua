return {
  ["0.1.13"] = function()
    for _, fcpu in pairs(global.fcpus) do
      if fcpu.valid then
        local state = Entity.get_data(fcpu)
        if state then
          state.entity = fcpu
          Entity.set_data(fcpu, state)
        end
      end
    end
  end
}
