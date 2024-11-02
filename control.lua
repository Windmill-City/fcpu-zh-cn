Entity = require('3rdparty.stdlib.entity')
table = require('3rdparty.flib061.table')
Heap = require('src.utils.Heap')

require('src/constants')
Profiler = require('src/debug')
Controller = require('src/cpu/controller')

require('src/storage')
require('src/gui/base')
require('src/fcpu_entity')
require('src/wiki')

-------------------------------------------------------------------------------------------------------

local function on_build_fcpu(event)
  local entity = event.entity
  if not (entity and entity.valid) then return end

  handle_fcpu_create(entity, event.tags and event.tags.fcpu)
end

local function on_destroy_fcpu(registration_number, soft)
  local state = get_destroyed_fcpu_state(registration_number)
  if not state then return end
  GuiEntityCloseWidget(state.unit_number)
  handle_fcpu_destroy(state, soft)
end

local function on_died_fcpu(event)
  local entity = event.entity
  if not (entity and entity.valid) then return end

  GuiEntityCloseWidget(entity.unit_number)
  handle_fcpu_died(entity)
end

local function update_gui()
  for _, player in pairs(game.players) do
    local player_data = get_player_data(player.index)
    if player_data and player_data.current_fcpu and player_data.gui_fcpu and player_data.gui_fcpu.valid then
      if player_data.current_fcpu.valid then
        local state = get_fcpu_state(player_data.current_fcpu)
        if state then
          GuiWidgetUpdate(player_data, state)
        end
      else
        GuiWidgetClose(player.index)
      end
    end
  end
end

--script.on_nth_tick(fcpu_gui_updates_every_tick, function(event)
--  update_gui()
--end)

script.on_event(defines.events.on_tick, function(event)
  local handled = 0
  local enabled = 0
  local start = storage.last_index

  local HandleCPU = function(index, k)
    local state = storage.fcpus[index]
    handled = handled + 1
    if Controller.handle(state) then
        enabled = enabled + 1
    end
    return nil, not state.destroy_regnum, start == k
  end

  -- TODO: add explicit HandleCPU call for deffered fCPUs!
  Controller.do_deferred()

  local limit = fcpu_maximum_updates_per_tick
  local ended
  storage.last_index, _, ended = table.for_n_of(storage.running, storage.last_index, limit, HandleCPU)
  if start and ended and handled < limit then
    storage.last_index = table.for_n_of(storage.running, nil, limit - handled, HandleCPU)
  end

  if (storage.gui_update_on_tick or 0) <= game.tick then
    storage.gui_update_on_tick = game.tick + fcpu_gui_updates_every_tick
    update_gui()
  end
end)

script.on_event(Controller.event_error, function(event)
  local entity = event.entity
  for _, player in pairs(game.players) do
    local player_data = get_player_data(player.index)
    if player_data.gui_fcpu and player_data.gui_fcpu.valid then
      if Entity._are_equal(entity, player_data.current_fcpu) then
        player_data.gui_error_message.caption = event.message or ""
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
      local src_state = get_fcpu_state(src_entity)
      local dst_state = get_fcpu_state(dst_entity)

      if src_state and dst_state then
        fcpu_update_program(dst_entity, src_state.program_text)
        Controller.compile(dst_state)
        Controller.set_program_counter(dst_state, 1) -- src_state.instruction_pointer)
        if Controller.is_running(src_state) then
          Controller.run(dst_state)
        end
      end
    end
  end
end

local function setup_blueprint_tag(blueprint, index, entity)
  local state = get_fcpu_state(entity)
  if state then
    blueprint.set_blueprint_entity_tag(index, 'fcpu', {
      t = state.program_text,
      i = state.instruction_pointer,
      r = Controller.is_running(state),
      d = state.disabled,
      n = state.custom_name,
    })
  end
end

local hackBP_unsaved
local function on_player_setup_blueprint(event)
  local player = game.players[event.player_index]
  if player then
    local blueprint = nil
    if player.blueprint_to_setup and player.blueprint_to_setup.valid_for_read then
      blueprint = player.blueprint_to_setup
    elseif player.cursor_stack and player.cursor_stack.valid_for_read and player.cursor_stack.name == 'blueprint' then
      blueprint = player.cursor_stack
    end

    if blueprint then
      local mapping = event.mapping.get()
      local entities = blueprint.get_blueprint_entities()

      if #mapping == 0 and entities and 0 < #entities then
        local pos2idx = {}
        for _,v in ipairs(entities) do
          if v.name == 'fcpu' then
            local pos = v.position.x ..';'.. v.position.y
            pos2idx[pos] = v.entity_number
          end
        end

        if next(pos2idx) then
          --if game.active_mods['attach-notes'] then
          --  player.print({"fcpu-errors.blueprint-broken", "Attach Notes"}, {r=0.5, g=0.5})
          --  player.print({"fcpu-errors.blueprint-unavailable", "Attach Notes"}, {r=0.5})
          --end
          local ents = player.surface.find_entities_filtered{name = 'fcpu', area = event.area, force = player.force}
          for _,ent in ipairs(ents) do
            local pos = ent.position.x ..';'.. ent.position.y
            local idx = pos2idx[pos]
            if idx then
              setup_blueprint_tag(blueprint, idx, ent)
            end
          end
        end
      else
        for idx, ent in pairs(mapping) do
          if ent.name == 'fcpu' then
            local success = pcall(setup_blueprint_tag, blueprint, idx, ent)
            if not success then
              hackBP_unsaved = hackBP_unsaved or {}
              hackBP_unsaved[idx] = ent
            end
          end
        end
        if hackBP_unsaved then
          hackBP_unsaved = nil

          -- https://forums.factorio.com/viewtopic.php?f=48&t=88100
          player.print({"fcpu-errors.blueprint-broken", "Factorio API"}, {r=0.5, g=0.5})
          player.print({"fcpu-errors.blueprint-unavailable", "Factorio API"}, {r=0.5})
        end
      end
    end
  end
end

local function on_entity_cloned(event)
  local dst_entity = event.destination
  if not (dst_entity and dst_entity.valid) then return end

  if string.find(dst_entity.name, '-fcpu') then
    dst_entity.destroy()
    return
  end

  if dst_entity.name == "fcpu" then
    local src_entity = event.source
    if not (src_entity and src_entity.valid) then return end

    if src_entity.name == "fcpu" then
      local src_state = get_fcpu_state(src_entity)
      if src_state then
        local dst_state = table.deep_copy(src_state)

        dst_state.program_ics = {}
        dst_state.index = nil
        register_fcpu(dst_entity, dst_state)
        Controller.verify(dst_state)
        Controller.compile(dst_state)
      end
    end
  end
end

-------------------------------------------------------------------------------------------------------
local function on_picker_dolly_moved(event)
  if event and event.moved_entity then
    local entity = event.moved_entity
    if entity.name == 'fcpu' then
      local state = get_fcpu_state(entity)
      if state then
        local fcpu = state.entity

        local offset_x = fcpu.position.x - event.start_pos.x
        local offset_y = fcpu.position.y - event.start_pos.y

        if state.program_ics then
          for _, ics in pairs(state.program_ics) do
            if ics and is_entity(ics) and ics.valid then
              ics.teleport{x = ics.position.x + offset_x, y = ics.position.y + offset_y}
            else
              for _, e in pairs(ics) do
                if e and is_entity(e) and e.valid then
                  e.teleport{x = e.position.x + offset_x, y = e.position.y + offset_y}
                end
              end
            end
          end
        end
      end
    end
  end
end

function register_picker_dolly_handler()
  if remote.interfaces["PickerDollies"] and remote.interfaces["PickerDollies"]["dolly_moved_entity_id"] then
    script.on_event(remote.call("PickerDollies", "dolly_moved_entity_id"), on_picker_dolly_moved)
  end
end

-------------------------------------------------------------------------------------------------------
local event = require("3rdparty.flib061.event")
local event_filters = {
  {filter = "name", name = "fcpu"},
}

event.register({
  defines.events.script_raised_built,
  defines.events.script_raised_revive,
  },
  function(event)
    on_build_fcpu(event)
  end
)

event.register({
  defines.events.script_raised_destroy,
  },
  function(event)
    --on_destroy_fcpu(event.unit_number)
  end
)

event.register({
  defines.events.on_object_destroyed},
  function(event)
    on_destroy_fcpu(event.registration_number, true)
  end
)

event.register({
  defines.events.on_pre_ghost_deconstructed,
  defines.events.on_player_mined_entity
  },
  function(event)
    if event.ghost then
      on_destroy_fcpu(event.ghost.unit_number)
    elseif event.entity then
      if event.entity.name == 'entity-ghost' then
        on_destroy_fcpu(event.entity.ghost_unit_number)
      else
        on_destroy_fcpu(event.entity.unit_number)
      end
    end
  end,
  {{filter = "name", name = "entity-ghost"}, {filter = "name", name = "fcpu"}}
)

event.register({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  },
  on_build_fcpu,
  {{filter = "name", name = "entity-ghost"}, unpack(event_filters)}
)

event.register({
  defines.events.on_entity_died,
  --defines.events.on_robot_pre_mined,
  --defines.events.on_pre_player_mined_item,
  },
  on_died_fcpu,
  {{filter = "name", name = "entity-ghost"}, unpack(event_filters)}
)

event.register(
  defines.events.on_entity_settings_pasted,
  on_entity_settings_pasted
)

event.register(
  defines.events.on_player_setup_blueprint,
  on_player_setup_blueprint
)

event.register(
  defines.events.on_entity_cloned,
  on_entity_cloned
)
