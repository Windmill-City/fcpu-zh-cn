
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
  return Entity.get_data(entity)
end

function set_fcpu_state(entity, state)
  Entity.set_data(entity, state)
end
