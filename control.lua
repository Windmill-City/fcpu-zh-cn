Entity = require('__stdlib__/stdlib/entity/entity')
table = require('__flib__.table')

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

local function on_destroy_fcpu(unit_number, soft)
  local fake = { unit_number = unit_number, valid = true, name = 'fcpu' }
  GuiEntityCloseWidget(fake)
  handle_fcpu_destroy(fake, soft)
end

local function on_died_fcpu(event)
  local entity = event.entity
  if not (entity and entity.valid) then return end

  GuiEntityCloseWidget(entity)
  handle_fcpu_died(entity)
end

script.on_nth_tick(fcpu_gui_updates_every_tick, function(event)
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
end)

local function sufficient_power(cpu)
  if cpu.is_connected_to_electric_network() then
    return cpu.electric_buffer_size <= cpu.energy
  end
end

script.on_event(defines.events.on_tick, function(event)
  local handled = 0
  local enabled = 0
  local start = global.last_index

  local HandleCPU = function(state, k)
    handled = handled + 1
    if state.entity and state.entity.valid then
      local need_sync = 0
      if state.deffered and next(state.deffered) ~= nil then
        need_sync = Controller.do_defferred(state, 1)
      end
      if not state.disabled and state.entity.active then
        if state.clock % 10 == 0 then
          state.out_out_power = not sufficient_power(state.entity)
        end
        if not state.out_out_power then
          if state.modified then
            Controller.compile(state)
            Controller.set_program_counter(state, state.instruction_pointer)
            Controller.update_state(state)
          end
          Controller.tick(state, need_sync)
        end
        enabled = enabled + 1
      end
    end
    return nil, not state.destroy_regnum, start == k
  end

  local limit = fcpu_maximum_updates_per_tick
  local ended
  global.last_index, _, ended = table.for_n_of(global.fcpus, global.last_index, limit, HandleCPU)
  if start and ended and handled < limit then
    global.last_index = table.for_n_of(global.fcpus, nil, limit - handled, HandleCPU)
  end
end)

script.on_event(Controller.event_error, function(event)
  local entity = event.entity
  for _, player in pairs(game.players) do
    local player_data = get_player_data(player.index)
    if player_data.gui_fcpu and player_data.gui_fcpu.valid then
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
      local src_state = get_fcpu_state(src_entity)
      if src_state then
        local dst_state = table.deep_copy(src_state)

        dst_state.imposter_fcpu = nil
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
    --on_destroy_fcpu(event.unit_number)
  end
)

event.register({
  defines.events.on_entity_destroyed},
  function(event)
    on_destroy_fcpu(event.unit_number, true)
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
