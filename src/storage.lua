
-------------------------------------------------------------------------------------------------------

function get_player_data(player_index)
  if global.player_data == nil then
    global.player_data = {}
  end
  local player = game.players[player_index]
  if (player and player.valid) then
    local player_data = global.player_data[player_index] or {}
    return player_data, player
  end
end

function set_player_data(player_index, data)
  if global.player_data == nil then
    global.player_data = {}
  end
  global.player_data[player_index] = data
end

-------------------------------------------------------------------------------------------------------

function register_fcpu(entity, state)
  state.destroy_regnum = script.register_on_entity_destroyed(entity)
  state.entity = entity
  state.index = #global.fcpus + 1
  global.fcpus[state.index] = state
  Entity.set_data(entity, state.index)
end

function destroy_fcpu(entity, state)
  Entity.set_data(entity, nil)
  if state then
    state.destroy_regnum = nil
  end
end

function get_fcpu_state(entity)
  if not (entity and entity.valid) then return end
  local index = Entity.get_data(entity)
  return global.fcpus[index]
end

function set_fcpu_state(entity, state)
  --Entity.set_data(entity, state.index)
end
