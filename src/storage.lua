
-------------------------------------------------------------------------------------------------------

function get_player_data(player_index)
  if global.player_data == nil then
    global.player_data = {}
  end
  local player = game.players[player_index]
  if (player and player.valid) then
    if not global.player_data[player_index] then
      global.player_data[player_index] = {}
    end
    return global.player_data[player_index], player
  end
end

-------------------------------------------------------------------------------------------------------

function register_fcpu(entity, state)
  state.destroy_regnum = script.register_on_object_destroyed(entity)
  state.unit_number = entity.unit_number
  state.entity = entity
  if not (state.index and global.fcpus[state.index]) then
    state.index = #global.fcpus + 1
  end
  global.fcpus[state.index] = state
  global.running[state.index] = state.index
  global.unmap[state.unit_number] = state.index
  global.destroy[state.destroy_regnum] = state.index
end

function destroy_fcpu(state)
  if not state then
    return
  end
  global.fcpus[state.index] = nil
  global.running[state.index] = nil
  global.unmap[state.unit_number] = nil
  global.destroy[state.destroy_regnum] = nil
  state.destroy_regnum = nil
end

function get_fcpu_state(entity)
  if not (entity and entity.valid) then return end
  if not global.unmap then
    local index = Entity.get_data(entity)
    Entity.set_data(entity, nil)
    return global.fcpus[index]
  end
  local index = global.unmap[entity.unit_number]
  local state = global.fcpus[index]
  debug_assert(not state or entity.unit_number == state.unit_number)
  return state
end

function get_destroyed_fcpu_state(registration_number)
  local index = global.destroy[registration_number]
  if not index then return end
  local state = global.fcpus[index]
  debug_assert(state.destroy_regnum == registration_number)
  return state
end
