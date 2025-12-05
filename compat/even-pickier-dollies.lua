local function on_picker_dolly_moved(event)
  if event and event.moved_entity then
    local entity = event.moved_entity
    if is_fcpu(entity) then
      local state = get_fcpu_state(entity)
      if state then
        Controller.teleport_to(state, event.start_pos)
      end
    end
  end
end

function register_picker_dolly_handler()
  if remote.interfaces["PickerDollies"] and remote.interfaces["PickerDollies"]["dolly_moved_entity_id"] then
    script.on_event(remote.call("PickerDollies", "dolly_moved_entity_id"), on_picker_dolly_moved)
  end
end

return {
  on_init = register_picker_dolly_handler,
  on_load = register_picker_dolly_handler,
}