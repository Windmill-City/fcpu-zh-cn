--[[
[table] state               = Entity.get_data([entity name="fcpu"])
[table] imposter_state      = Entity.get_data([entity name="imposter-fcpu"])
[entity] fcpu               = imposter_state.fcpu
[entity] imposter_fcpu      = state.imposter_fcpu
--]]

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

function get_fcpu_state(entity)
  if not (entity and entity.valid) then return end
  if entity.name == "fcpu" then
    local state = Entity.get_data(entity)
    return state
  end
  if entity.name == "imposter-fcpu" then
    local imposter_state = Entity.get_data(entity)
    if imposter_state then
      return get_fcpu_state(imposter_state.fcpu)
    end
  end
end
