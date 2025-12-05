function register_compaktcircuit_handler()
  if remote.interfaces['compaktcircuit'] and remote.interfaces['compaktcircuit']['add_combinator'] then
  else
    return
  end

  local driver = {
    name = 'fcpu',
    packed_names = { 'fcpu', 'fcpu-packed' },
    interface_name = 'fcpu_compaktcircuit'
  }

  remote.call('compaktcircuit', 'add_combinator', driver)

  remote.add_interface(driver.interface_name, {
    get_info = function(entity)
      local state = get_fcpu_state(entity)
      if state then
        local tag = create_fcpu_tag_for(state)
        return { fcpu = tag }
      end
    end,

    create_packed_entity = function(info, surface, position, force)
        local entity = surface.create_entity { name = 'fcpu-packed', force = force, position = position, direction = info.direction }
        handle_fcpu_create(entity, info.fcpu)
        return entity
    end,

    create_entity = function(info, surface, force)
        local entity = surface.create_entity { name = driver.name, force = force, position = info.position, direction = info.direction }
        handle_fcpu_create(entity, info.fcpu)
        return entity
    end
  })
end

return {
  on_init = register_compaktcircuit_handler,
  on_load = register_compaktcircuit_handler,
}