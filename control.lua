Entity = require('__stdlib__/stdlib/entity/entity')
Surface = require('__stdlib__/stdlib/area/surface')
require('__stdlib__/stdlib/area/tile')
table = require('__stdlib__/stdlib/utils/table')

require('src/constants')
Profiler = require('src/debug')
Controller = require('src/cpu/controller')

require('src/storage')
require('src/gui')
require('src/fcpu_entity')
require('src/wiki')

-------------------------------------------------------------------------------------------------------

local function on_build_fcpu(event)
  local entity = event.created_entity
  if not (entity and entity.valid) then return end

  handle_fcpu_create(entity, event.tags and event.tags.fcpu)
end

local function on_destroy_fcpu(event)
  local entity = event.entity
  if not (entity and entity.valid and entity.unit_number) then return end

  GuiEntityCloseWidget(entity)
  handle_fcpu_destroy(entity)
end

script.on_nth_tick(fcpu_gui_updates_every_tick, function(event)
  for _, player in pairs(game.players) do
    local player_data = get_player_data(player.index)
    if player_data and player_data.current_fcpu and player_data.gui_fcpu then
      if player_data.current_fcpu.valid then
        local state = Entity.get_data(player_data.current_fcpu)
        if state then
          GuiWidgetUpdate(player_data, state)
        end
      else
        GuiWidgetClose(player.index)
      end
    end
  end
end)

local function sufficient_power(cpu)
  if cpu.is_connected_to_electric_network() then
    return cpu.electric_buffer_size <= cpu.energy
  end
end

script.on_event(defines.events.on_tick, function(event)
  global.last_index = global.last_index or #global.fcpus

  local limit = math.min(#global.fcpus, fcpu_maximum_updates_per_tick)
  local i = 1
  local c = 1
  while i <= limit and c <= #global.fcpus do
    global.last_index = (global.last_index + #global.fcpus - 2) % #global.fcpus + 1

    -- Iterate through stored fcpus
    local cpu = global.fcpus[global.last_index]
    if cpu.valid then
      local state = Entity.get_data(cpu)
      if state then
        local need_sync = 0
        if state.deffered and next(state.deffered) ~= nil then
          need_sync = Controller.do_defferred(state, 1)
        end
        -- Tick the Controller
        if not state.disabled and cpu.active then
          if sufficient_power(cpu) then
            Controller.tick(state, need_sync)
            Entity.set_data(cpu, state)
          end
          i = i + 1
        end
      end
    else
      GuiEntityCloseWidget(cpu)
      --table.remove(global.fcpus, global.last_index)
      global.fcpus[global.last_index] = global.fcpus[#global.fcpus]
      global.fcpus[#global.fcpus] = nil
    end

    c = c + 1
  end
end)

script.on_event(Controller.event_error, function(event)
  local entity = event.entity
  for _, player in pairs(game.players) do
    local player_data = get_player_data(player.index)
    if player_data.gui_fcpu then
      if Entity._are_equal(entity, player_data.current_fcpu) then
        player_data.gui_error_message.caption = event.message
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
        Controller.compile(dst_state)
        Controller.set_program_counter(dst_state, 1) -- src_state.instruction_pointer)
        if Controller.is_running(src_state) then
          Controller.run(dst_state)
        end
        Entity.set_data(dst_entity, dst_state)
      end
    end
  end
end

local function on_player_setup_blueprint(event)
  local player = game.players[event.player_index]
  local blueprint = nil
  if player and player.blueprint_to_setup and player.blueprint_to_setup.valid_for_read then
    blueprint = player.blueprint_to_setup
  elseif player and player.cursor_stack.valid_for_read and player.cursor_stack.name == "blueprint" then
    blueprint = player.cursor_stack
  end
  if blueprint then
    for index, entity in pairs(event.mapping.get()) do
      if entity.name == 'fcpu' then
        local state = get_fcpu_state(entity)
        if state then
          blueprint.set_blueprint_entity_tag(index, "fcpu", {
            t = state.program_text,
            i = state.instruction_pointer,
            r = Controller.is_running(state),
            d = state.disabled
          })
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
      local src_state = Entity.get_data(src_entity)
      if src_state then
        local dst_state = table.deep_copy(src_state)

        if src_entity.name == "fcpu" then
          table.insert(global.fcpus, dst_entity)
          dst_state.entity = dst_entity
          dst_state.imposter_fcpu = nil
          dst_state.program_ics = {}
          Controller.compile(dst_state)
        else
          dst_state.entity = dst_entity
        end

        Entity.set_data(dst_entity, dst_state)
        if src_entity.name == "fcpu" then
          fcpu_verify_utility(dst_entity)
        end
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
            for _, e in pairs(ics) do
              if e and type(e) == 'table' and e.valid then
                e.teleport{x = e.position.x + offset_x, y = e.position.y + offset_y}
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
