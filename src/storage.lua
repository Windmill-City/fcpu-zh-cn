
-------------------------------------------------------------------------------------------------------

function get_player_data(player_index)
  if storage.player_data == nil then
    storage.player_data = {}
  end
  local player = game.players[player_index]
  if (player and player.valid) then
    if not storage.player_data[player_index] then
      storage.player_data[player_index] = {}
    end
    return storage.player_data[player_index], player
  end
end

-------------------------------------------------------------------------------------------------------

function register_fcpu(entity, state)
  state.destroy_regnum = script.register_on_object_destroyed(entity)
  state.unit_number = entity.unit_number
  state.entity = entity
  if not (state.index and storage.fcpus[state.index]) then
    state.index = #storage.fcpus + 1
  end
  storage.fcpus[state.index] = state
  storage.running[state.index] = state.index
  storage.unmap[state.unit_number] = state.index
  storage.destroy[state.destroy_regnum] = state.index
end

function destroy_fcpu(state)
  if not state then
    return
  end
  storage.fcpus[state.index] = nil
  storage.running[state.index] = nil
  storage.unmap[state.unit_number] = nil
  storage.destroy[state.destroy_regnum] = nil
  state.destroy_regnum = nil
end

function get_fcpu_state(entity)
  if not (entity and entity.valid) then return end
  if not storage.unmap then
    local index = Entity.get_data(entity)
    Entity.set_data(entity, nil)
    return storage.fcpus[index]
  end
  local index = storage.unmap[entity.unit_number]
  local state = storage.fcpus[index]
  debug_assert(not state or entity.unit_number == state.unit_number)
  return state
end

function get_destroyed_fcpu_state(registration_number)
  local index = storage.destroy[registration_number]
  if not index then return end
  local state = storage.fcpus[index]
  debug_assert(state.destroy_regnum == registration_number)
  return state
end
