require('__stdlib__/stdlib/area/tile')
local Surface = require("__stdlib__/stdlib/area/surface")
local Entity = require("__stdlib__/stdlib/entity/entity")

require('src/constants')

local microcontroller = require('src/microcontroller')
require('src/gui').setMicrocontroller(microcontroller)

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

script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity}, function(event)
  local entity = event.created_entity
  if not (entity and entity.valid) then return end

  if entity.name == "fcpu" then
    -- Init and insert new microcontroller to global state.
    microcontroller.init(entity, {})
    local didFind = false
    for _, mc in ipairs(global.fcpus) do
      if mc == entity then
        didFind = true
      end
    end
    if not didFind then
      table.insert(global.fcpus, entity)
    end
  end
end)

-- Handle fCPU ERROR event.
script.on_event(microcontroller.event_error, function(event)
  local mc = event.entity
  for _, player in pairs(game.players) do
    local player_data = get_player_data(player.index)
    if player_data.current_fcpu_gui then
      player_data.current_fcpu_gui.outer.error_message.caption = event.message
    end
  end
end)

-- Handle fCPU HALT event.
script.on_event(microcontroller.event_halt, function(event)
  local mc = event.entity
  for _, player in pairs(game.players) do
    local player_data = get_player_data(player.index)
    if player.opened == player_data.current_fcpu and player_data.current_fcpu then
      local state = Entity.get_data(player_data.current_fcpu)
      player.opened = nil
      Entity.set_data(player_data.current_fcpu, state)
    end
  end
end)

function signalToSpritePath(signal)
  if signal.type == "virtual" then
    return "virtual-signal/" .. signal.name
  else
    return signal.type .. '/' .. signal.name
  end
end

script.on_event(defines.events.on_tick, function(event)
  -- Ensure we have a table to store fcpus in the global state.
  if not global.fcpus then
    global.fcpus = {}
  end
  -- Iterate through all stored fcpus.
  for i = #global.fcpus, 1, -1 do
    local mc = global.fcpus[i]
    if mc.valid then
      local state = Entity.get_data(mc)
      if state then
        -- Enable/Disable the run/step button.
        if state.gui_run_button and state.gui_run_button.valid then
          if microcontroller.is_running(mc) then
            state.gui_halt_button.enabled = true
            state.gui_run_button.enabled = false
            state.gui_enable_switch.switch_state = "right"
          else
            state.gui_halt_button.enabled = (state.program_counter ~= 1)
            state.gui_run_button.enabled = true
            state.gui_enable_switch.switch_state = "left"
          end
        end
        -- Make text read-only while running
        if state.gui_program_input and state.gui_program_input.valid then
          state.gui_program_input.read_only = microcontroller.is_running(mc)
        end
        -- Update the program lines in the GUI.
        if state.gui_line_numbers and state.gui_line_numbers.valid then
          updateLines(state.gui_line_numbers, state)
        end
        -- Update the inspector GUI.
        if state.gui_inspector and state.gui_inspector.valid then
          for i = 1, 4 do
            state.gui_inspector['mem'..i..'-inspect'].sprite = signalToSpritePath( state.memory[i].signal)
            state.gui_inspector['mem'..i..'-inspect'].number = state.memory[i].count
          end
        end
        -- Tick the microcontroller.
        microcontroller.tick(mc, state)
      end
    else
      -- Microcontroller no longer exists, remove from global state.
      for player_index, player in pairs(game.players) do
        local player_data = get_player_data(player_index)
        if player_data.current_fcpu_gui and player_data.current_fcpu_gui.valid then
          player_data.current_fcpu_gui.destroy()
          player_data.current_fcpu_gui = nil
        end
        set_player_data(player_index, player_data)
      end
      table.remove(global.fcpus, i)
    end
  end
end)

script.on_event(defines.events.on_entity_settings_pasted, function(event)
  local dst_entity = event.destination
  if not (dst_entity and dst_entity.valid) then return end

  if dst_entity.name == "fcpu" then
    local src_entity = event.source
    if not (src_entity and src_entity.valid) then return end

    -- TODO: handle "arithmetic-combinator", "decider-combinator"

    if src_entity.name == "fcpu" then
      local src_state = Entity.get_data(src_entity)
      local dst_state = Entity.get_data(dst_entity)

      if src_state and dst_state then
        microcontroller.update_program_text(dst_entity, src_state.program_text)
        microcontroller.set_program_counter(dst_entity, dst_state, src_state.program_counter)
      end
    end
  end
end)

