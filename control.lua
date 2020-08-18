Entity = require('__stdlib__/stdlib/entity/entity')
Surface = require('__stdlib__/stdlib/area/surface')
require('__stdlib__/stdlib/area/tile')
table = require('__stdlib__/stdlib/utils/table')

require('src/constants')
Profiler = require('src/debug')
Controller = require('src/controller')

require('src/storage')
require('src/gui')
require('src/fcpu_entity')

-------------------------------------------------------------------------------------------------------

local function on_build_fcpu(event)
  local entity = event.created_entity
  if not (entity and entity.valid) then return end

  handle_fcpu_create(entity)
end

local function on_destroy_fcpu(event)
  local entity = event.entity
  if not (entity and entity.valid and entity.unit_number) then return end

  debug_print("entity destroyed #", entity.unit_number)
  GuiEntityCloseWidget(entity)

  if event.name == defines.events.on_entity_died then
    -- after entity die there will be ghost leaved for entity reviving, so do not remove fcpu imposter
    handle_fcpu_destroy(entity)
  end

  fcpu_destroy_imposter(entity)
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

global.profile = false

script.on_event(defines.events.on_tick, function(event)
  -- Ensure we have a table to store fcpus in the global state.
  if not global.fcpus then
    global.fcpus = {}
  end

  global.last_index = global.last_index or #global.fcpus
  if global.profile_ticks and Profiler then Profiler.Start(true) end

  local limit = math.min(#global.fcpus, global.profile_ticks or fcpu_maximum_updates_per_tick)
  local i = 1
  local c = 1
  while i <= limit and c <= #global.fcpus do
    global.last_index = (global.last_index + #global.fcpus - 2) % #global.fcpus + 1
    c = c + 1

    -- Iterate through stored fcpus
    local cpu = global.fcpus[global.last_index]
    if cpu.valid then
      local state = Entity.get_data(cpu)
      if state and not state.disabled then
        GuiWidgetUpdate(cpu, state)
        -- Tick the Controller
        if cpu.active and cpu.is_connected_to_electric_network() then
          Controller.tick(cpu, state)
          i = i + 1
        end
      end
    else
      GuiEntityCloseWidget(cpu)
      table.remove(global.fcpus, global.last_index)
    end
  end

  if global.profile_ticks and Profiler then Profiler.Stop(false, "") global.profile_ticks = nil end
end)

script.on_event(Controller.event_error, function(event)
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
        Controller.compile(dst_entity, dst_state)
        Controller.set_program_counter(dst_entity, dst_state, 1) -- src_state.instruction_pointer)
        if Controller.is_running(src_entity) then
          Controller.run(dst_entity, dst_state)
        end
      end
    end
  end
end

-------------------------------------------------------------------------------------------------------
local event = require("__flib__.event")
local event_filters = {
  {filter = "name", name = "fcpu"},
  {filter = "name", name = "imposter-fcpu"},
}

event.register({
  defines.events.script_raised_built,
  defines.events.script_raised_revive,
  },
  function(event)
    on_build_fcpu({ created_entity = event.entity })
  end
)

event.register({
  defines.events.script_raised_destroy,
  },
  function(event)
    on_destroy_fcpu(event)
  end
)

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
