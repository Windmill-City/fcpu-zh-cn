-- require('mod-gui')

local string = require('__stdlib__/stdlib/utils/string')
local gui = require("__flib__.gui")

-------------------------------------------------------------------------------------------------------

function mixPlayerData(event, proc)
  return function(event)
    local player_data, player = get_player_data(event.player_index)
    proc(player_data, player, event)
    set_player_data(event.player_index, player_data)
  end
end

gui.add_handlers{
  widget = {
    close_button = {
      on_gui_click = function(event)
        fcpuCloseWidget(event.player_index)
      end
    },
    program_input = {
      on_gui_text_changed = mixPlayerData(event, function(player_data, player, event)
        local element = event.element
        local lines = {};
        for m in (element.text..'\n'):gmatch("(.-)\n") do
            table.insert(lines, m);
        end
        if #lines > MC_LINES or #lines == MC_LINES and lines[#lines] == '\n' then
          local c = #lines - MC_LINES
          for i = 1, MC_LINES do
            if c == 0 then break end
            if lines[i] == "" then
              table.remove(lines, i)
              c = c - 1
            end
          end
          if 0 < c then
            for i = 1, c do
              table.remove(lines, #lines)
            end
          end
          element.text = table.concat(lines, '\n')
        end
        fcpu_update_program(player_data.current_fcpu, element.text)
      end)
    },
    enable_program = {
      on_gui_switch_state_changed = mixPlayerData(event, function(player_data, player, event)
        local state = Entity.get_data(player_data.current_fcpu)
        if event.element then
          if event.element.switch_state == "right" then
            if not Controller.is_running(player_data.current_fcpu) then
              player_data.current_fcpu_gui.outer.error_message.caption = ""
              Controller.compile(player_data.current_fcpu, state)
              Controller.run(player_data.current_fcpu, state)
            end
            state.disabled = nil
          else
            Controller.halt(player_data.current_fcpu, state)
            state.disabled = true
          end
          Entity.set_data(player_data.current_fcpu, state)
        end
      end)
    },
    run_program = {
      on_gui_click = mixPlayerData(event, function(player_data)
        local state = Entity.get_data(player_data.current_fcpu)
        player_data.current_fcpu_gui.outer.error_message.caption = ""
        Controller.compile(player_data.current_fcpu, state)
        Controller.run(player_data.current_fcpu, state)
      end)
    },
    halt_program = {
      on_gui_click = mixPlayerData(event, function(player_data)
        local state = Entity.get_data(player_data.current_fcpu)
        Controller.halt(player_data.current_fcpu, state)
      end)
    },
    step_program = {
      on_gui_click = mixPlayerData(event, function(player_data)
        local state = Entity.get_data(player_data.current_fcpu)
        player_data.current_fcpu_gui.outer.error_message.caption = ""
        Controller.compile(player_data.current_fcpu, state)
        Controller.step(player_data.current_fcpu, state)
      end)
    },
    copy_program = {
      on_gui_click = mixPlayerData(event, function(player_data)
        player_data.program_clipboard = player_data.current_fcpu_gui.outer.inner['program-input'].text
      end)
    },
    paste_program = {
      on_gui_click = mixPlayerData(event, function(player_data)
        if player_data.program_clipboard then
          player_data.current_fcpu_gui.outer.inner['program-input'].text = player_data.program_clipboard
        end
      end)
    },
  }
}

gui.add_templates{
  pushers = {
    horizontal = {type="empty-widget", style_mods={horizontally_stretchable=true}},
    vertical = {type="empty-widget", style_mods={vertically_stretchable=true}}
  },
  frame_title = {type="label", style="frame_title"},
  frame_action_button = {type="sprite-button", style="frame_action_button", mouse_button_filter={"left"}},
  drag_handle = {type="empty-widget", style="draggable_space_header", style_mods={minimal_width=30, height=24, right_margin=4, horizontally_stretchable=true}},
  close_button = {template="frame_action_button", sprite="utility/close_white", hovered_sprite="utility/close_black"},
  heading_2 = {type="frame", style="invisible_frame_with_title", children={type="label", style="heading_2_label", caption="caption"}},
  control_button = function(name, sprite, color)
    return {type="sprite-button", style="tool_button"..(color and "_"..color or ""), style_mods={}, name=name.."-program", sprite="fcpu-"..sprite.."-sprite", save_as="gui_"..name.."_button", handlers="widget."..name.."_program"}
  end,
  slot_button = function(name)
    return {type="sprite-button", style="slot_button_in_shallow_frame", name=""..name.."-inspect", tooltip=""..name..""}
  end,
}

function CreateWidget(player)
  local rootGui = player.gui.screen -- mod_gui.get_frame_flow({gui={left=player.gui.screen}})
  if rootGui["fcpu-widget"] then
    rootGui["fcpu-widget"].destroy()
  end

  local memslots = {}
  for i = 1, MC_MEMORY do
    table.insert(memslots, gui.templates.slot_button("mem"..i))
  end

  local elems = gui.build(rootGui, {
    {type="frame", save_as="gui_fcpu", name="fcpu-widget", style="inner_frame_in_outer_frame", direction="vertical", children={
      {type="flow", name="titlebar", children={
        {template="frame_title", name="label", caption="fcpu"},
        {template="drag_handle", name="drag_handle"},
        {template="close_button", save_as="gui_exit_button", handlers="widget.close_button"},
      }},

      {type="frame", name="outer", style="inside_shallow_frame_with_padding", direction="vertical", children={
        {type="flow", name="buttons_row", direction="horizontal", style_mods={vertical_align="center"}, children={
          --gui.templates.control_button("copy", "copy"),
          --gui.templates.control_button("paste", "paste"),
          --{template="pushers.horizontal"},
          gui.templates.control_button("halt", "stop", "red"),
          gui.templates.control_button("step", "next"),
          gui.templates.control_button("run", "play", "green"),
          {template="pushers.horizontal"},
          {type="switch", style_mods={ right_margin=10 }, left_label_caption={"gui-constant.off"}, right_label_caption={"gui-constant.on"}, save_as="gui_enable_switch", handlers="widget.enable_program"},
        }},
        {template="heading_2", caption={"gui-fcpu.memory"}},
        {type="flow", save_as="gui_inspector", direction="horizontal",
          children={
            table.unpack(memslots)
          },
          style_mods={horizontally_stretchable=true, horizontal_align="center"},
        },
        {template="heading_2", caption={"gui-fcpu.program"}},
        {type="scroll-pane", style_mods={maximal_height=490}, horizontal_scroll_policy="never", children={
          {type="flow", name="inner", style_mods={}, direction="horizontal",
            children={
              {type="text-box", style="fcpu_notice_textbox", save_as="gui_line_numbers",
                ignored_by_interaction=true,
              },
              {type="text-box", name="program-input", style="fcpu_program_input",
                style_mods={
                  vertically_stretchable=false,
                  horizontally_stretchable=true,
                },
                horizontal_scroll_policy="never",
                vertical_scroll_policy="never",
                handlers="widget.program_input",
                save_as="gui_program_input",
              },
            },
            style_mods={horizontally_stretchable=false, vertically_squashable=true},
          },
        }},
        {type="label", name="error_message", caption="", style="bold_red_label"},
      }},

      {type="flow", name="footer", children={
        {template="drag_handle", name="drag_handle", style_mods={horizontally_stretchable=true, height=32}}
      }},
    }}
  })

  elems.gui_fcpu.titlebar.label.drag_target = elems.gui_fcpu
  elems.gui_fcpu.titlebar.drag_handle.drag_target = elems.gui_fcpu
  elems.gui_fcpu.footer.drag_handle.drag_target = elems.gui_fcpu

  return elems
end

function fcpuOpenWidget(player, entity)
  local player_data = get_player_data(player.index)
  local state = Entity.get_data(entity)

  local elems = CreateWidget(player)
  if fcpu_debug_enabled then
    elems.gui_fcpu.titlebar.label.caption = elems.gui_fcpu.titlebar.label.caption.." #"..entity.unit_number
  end
  state = table.merge(state, elems)

  state.gui_program_input.text = state.program_text
  updateLines(state.gui_line_numbers, state)

  if state.disabled then
    state.gui_enable_switch.switch_state = "left"
  else
    state.gui_enable_switch.switch_state = "right"
  end

  if Controller.is_running(entity) then
    state.gui_run_button.enabled = false
  else
    state.gui_run_button.enabled = true
  end

  player_data.current_fcpu_gui = state.gui_fcpu

  Entity.set_data(entity, state)
  set_player_data(player.index, player_data)

  player.play_sound{path="entity-open/"..player_data.current_fcpu.prototype.name, volume_modifier=0.85}

  return state.gui_fcpu
end

function updateLines(element, state)
  local lines = {}
  for i = 1, MC_LINES do
    local line = tostring(i)
    if i < 10 then line = "  "..i end
    if i == state.error_line then
      line = line..'!'
    elseif i == state.program_counter then
      line = line..'>'
    else
      line = line..' '
    end
    table.insert(lines, line)
  end
  element.text = table.concat(lines, "\n")
end

function fcpuCloseWidget(player_index, silent)
  local player_data, player = get_player_data(player_index)
  if player_data and player_data.current_fcpu and player_data.current_fcpu_gui then
    local state = Entity.get_data(player_data.current_fcpu)
    fcpu_update_program(player_data.current_fcpu, state.gui_program_input.text)
    player_data.current_fcpu.operable = true

    player_data.current_fcpu_gui.destroy()
    player_data.current_fcpu_gui = nil
    set_player_data(player.index, player_data)

    if not silent then
      player.play_sound{path="entity-close/"..player_data.current_fcpu.prototype.name, volume_modifier=0.85}
    end
  end
end

function close_entity_gui(entity)
  for player_index, player in pairs(game.players) do
    local player_data = get_player_data(player_index)
    if Entity._are_equal(entity, player_data.current_fcpu) then
      if player_data.current_fcpu_gui and player_data.current_fcpu_gui.valid then
        player_data.current_fcpu_gui.destroy()
        player_data.current_fcpu_gui = nil
      end
      player_data.current_fcpu = nil
      set_player_data(player_index, player_data)
    end
  end
end


gui.register_handlers()

-- Close default gui when it will be opened.
script.on_event(defines.events.on_gui_opened, function(event)
  if gui.dispatch_handlers(event) then return end

  local entity = event.entity
  if entity and entity.valid and entity.name == "fcpu" then
    local player_data, player = get_player_data(event.player_index)
    if player_data then
      player.opened = player_data.current_fcpu_widget
    end
  end
end)

-- Handle fCPU OPEN event.
script.on_event("fcpu-open", function(event)
  local player = game.players[event.player_index]
  local entity = player.selected
  if entity and entity.name == "fcpu" then
    if player.can_reach_entity(entity) then
      local player_data = get_player_data(event.player_index)

      if player_data.current_fcpu_gui and Entity._are_equal(player_data.current_fcpu, entity) then return end

      player_data.current_fcpu = entity
      set_player_data(event.player_index, player_data)

      fcpuOpenWidget(player, entity)
    end
  elseif entity then
    fcpuCloseWidget(event.player_index)
  end
end)

-- Handle fCPU GUI Close event.
script.on_event("fcpu-close", function(event)
  fcpuCloseWidget(event.player_index)
end)

-- Handle player move event to close GUI when out of range.
script.on_event(defines.events.on_player_changed_position, function(event)
  local player_data, player = get_player_data(event.player_index)
  if player_data and player_data.current_fcpu and player_data.current_fcpu_gui then
    if not player.can_reach_entity(player_data.current_fcpu) then
      fcpuCloseWidget(event.player_index, true)
    end
  end
end)


script.on_init(function()
  gui.init()
  gui.build_lookup_tables()
end)
script.on_load(function()
  gui.build_lookup_tables()
end)
script.on_configuration_changed(function()
  gui.init()
end)
