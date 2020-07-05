Entity = require('__stdlib__/stdlib/entity/entity')
Surface = require('__stdlib__/stdlib/area/surface')
require('__stdlib__/stdlib/area/tile')

controller = require('src/controller')
require('src/constants')
require('src/gui')
require('src/fcpu_entity')

--[[
[table] state               = Entity.get_data([entity name="fcpu"])
[table] imposter_state      = Entity.get_data([entity name="imposter-fcpu"])
[entity] fcpu               = imposter_state.fcpu
[entity] imposter_fcpu      = state.imposter_fcpu
--]]

local debug_enabled = 0

local function debug_print_real(...)
  local s = ""
  for _,v in ipairs({...}) do
    s = s .. tostring(v)
  end
  if (debug_enabled % 2) == 1 then
    game.print(s)
  end
  if (debug_enabled / 2 % 2) == 1 then
    log(s)
  end
end

if debug_enabled and 0 < debug_enabled then
  debug_print = debug_print_real
else
  debug_print = function()end
end

local function signalToSpritePath(signal)
  if signal.type == "virtual" then
    return "virtual-signal/" .. signal.name
  else
    return signal.type .. '/' .. signal.name
  end
end

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

local function on_build_fcpu(event)
  local entity = event.created_entity
  if not (entity and entity.valid) then return end

  if entity.name == "fcpu" then
    controller.init(entity, {})
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

  handle_fcpu_create(entity)
end

local function on_destroy_fcpu(event)
  debug_print("entity destroyed #"..event.entity.unit_number)
  close_entity_gui(event.entity)

  -- after entity die there will be ghost leaved for entity reviving, so do not remove fcpu imposter
  if event.name == defines.events.on_entity_died then
    local entity = event.entity
    if not (entity and entity.valid) then return end
    if entity.name == "fcpu" then
      -- move data from fcpu to its imposter so we can revive it later
      local imposter_fcpus = entity.surface.find_entities_filtered{name = "imposter-fcpu", position = entity.position, force = entity.force, limit = 1}
      if #imposter_fcpus > 0 then
        local imposter_fcpu = imposter_fcpus[1]
        if imposter_fcpu.valid then
          local imposter_state = get_imposter_fcpu_state(imposter_fcpu)
          if imposter_state ~= nil then
            local state = get_fcpu_state(entity)
            if state ~= nil then
              -- rendering.draw_line{from={entity.position.x+0.1, entity.position.y}, to=imposter_fcpu, width=5, color={b = 1, a = 0.8}, surface=entity.surface }
              debug_print("moved to imposter "..imposter_fcpu.unit_number)
              imposter_state.target_program = state.program_text
              imposter_state.ip = state.program_counter
              imposter_state.run = controller.is_running(entity)
              Entity.set_data(imposter_fcpu, imposter_state)
              return
            end
          end
        end
      end
    end
  end
  -- }

  fcpu_destroy_imposter(event.entity)
end

local function on_marked_for_deconstruction(event)
  local ent = event.entity

  if ent.name == "imposter-fcpu" then
    local imposter_state = get_imposter_fcpu_state(ent)
    if not (imposter_state.fcpu and imposter_state.fcpu.valid) or imposter_state.fcpu.name == "entity-ghost" then 
      Entity.set_data(ent, nil)
      ent.destroy()
    else
      -- if target is still valid, just cancel deconstruction
      local force = (event.player_index and game.players[event.player_index].force) or
                    (ent.last_user and ent.last_user.force) or
                    ent.force
      ent.cancel_deconstruction(force)
    end
  end
end

script.on_event(defines.events.on_tick, function(event)
  -- Ensure we have a table to store fcpus in the global state.
  if not global.fcpus then
    global.fcpus = {}
  end

  global.last_index = global.last_index or #global.fcpus
  for i = 1, 200 do
    global.last_index = (global.last_index + #global.fcpus - 2) % #global.fcpus + 1

    -- Iterate through stored fcpus.
    local mc = global.fcpus[global.last_index]
    if mc.valid then
      local state = Entity.get_data(mc)
      if state then
        -- Enable/Disable the run/step button.
        if state.gui_run_button and state.gui_run_button.valid then
          if controller.is_running(mc) then
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
          state.gui_program_input.read_only = controller.is_running(mc)
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
        -- Tick the controller.
        if mc.active and mc.is_connected_to_electric_network() then
          controller.tick(mc, state)
        end
      end
    else
      -- Microcontroller no longer exists, remove from global state.
      close_entity_gui(mc)
      table.remove(global.fcpus, i)
    end
  end
end)

script.on_event(controller.event_error, function(event)
  local entity = event.entity
  for _, player in pairs(game.players) do
    local player_data = get_player_data(player.index)
    if player_data.current_fcpu_gui then
      if Entity._are_equal(entity, player_data.current_fcpu) then
        player_data.current_fcpu_gui.outer.error_message.caption = event.message
      end
    end
  end
end)

local function on_entity_settings_pasted(event)
  local dst_entity = event.destination
  if not (dst_entity and dst_entity.valid) then return end

  if dst_entity.name == "fcpu" then
    local src_entity = event.source
    if not (src_entity and src_entity.valid) then return end

    -- TODO: handle "arithmetic-combinator", "decider-combinator", "constant-combinator"

    if src_entity.name == "fcpu" then
      local src_state = Entity.get_data(src_entity)
      local dst_state = Entity.get_data(dst_entity)

      if src_state and dst_state then
        fcpu_update_program(dst_entity, src_state.program_text)
        controller.compile(dst_entity, dst_state)
        controller.set_program_counter(dst_entity, dst_state, 1) -- src_state.program_counter)
        if controller.is_running(src_entity) then
          controller.run(dst_entity, dst_state)
        end
      end
    end
  end
end

--script.on_event(defines.events.on_player_setup_blueprint, function on_player_setup_blueprint(event)
--  debug_print("on_player_setup_blueprint")
--  debug_print(serpent.block(event))
--end)

-------------------------------------------------------------------------------------------------------
local event = require("__flib__.event")
local event_filters = {
  {filter = "name", name = "fcpu"},
  {filter = "name", name = "imposter-fcpu"},
}

event.register({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity},
  on_build_fcpu,
  table.merge(event_filters, {{filter = "name", name = "entity-ghost"}}, true)
)

event.register({
  defines.events.on_entity_died,
  defines.events.on_robot_pre_mined,
  defines.events.on_pre_player_mined_item},
  on_destroy_fcpu,
  table.merge(event_filters, {{filter = "name", name = "entity-ghost"}}, true)
)

event.register(
  defines.events.on_marked_for_deconstruction,
  on_marked_for_deconstruction,
  event_filters
)

event.register(
  defines.events.on_entity_settings_pasted,
  on_entity_settings_pasted
)
