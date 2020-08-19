-- require('mod-gui')

local gui = require("__flib__.gui")

-------------------------------------------------------------------------------------------------------

local function mixPlayerData(proc)
  return function(event)
    local player_data, player = get_player_data(event.player_index)
    proc(player_data, player, event)
    set_player_data(event.player_index, player_data)
  end
end

local function signalToSpritePath(signal)
  if signal then
    if signal.type == "virtual" then
      return "virtual-signal/" .. signal.name
    elseif signal.name then
      return signal.type .. '/' .. signal.name
    end
  end
end

gui.add_handlers{
  widget = {
    close_button = {
      on_gui_click = function(event)
        GuiWidgetClose(event.player_index)
      end
    },
    program_input = {
      on_gui_text_changed = mixPlayerData(function(player_data, player, event)
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
      on_gui_switch_state_changed = mixPlayerData(function(player_data, player, event)
        local state = Entity.get_data(player_data.current_fcpu)
        if event.element then
          if event.element.switch_state == "right" then
            state.disabled = nil
            if not Controller.is_running(state) then
              player_data.current_fcpu_gui.outer.error_message.caption = ""
              Controller.compile(state)
              Controller.run(state)
            end
          else
            state.disabled = true -- halt will clear output registers
            Controller.halt(state)
          end
          Entity.set_data(player_data.current_fcpu, state)
        end
      end)
    },
    run_program = {
      on_gui_click = mixPlayerData(function(player_data)
        local state = Entity.get_data(player_data.current_fcpu)
        player_data.current_fcpu_gui.outer.error_message.caption = ""
        Controller.compile(state)
        Controller.run(state)
        Entity.set_data(player_data.current_fcpu, state)
      end)
    },
    halt_program = {
      on_gui_click = mixPlayerData(function(player_data)
        local state = Entity.get_data(player_data.current_fcpu)
        Controller.halt(state)
        Entity.set_data(player_data.current_fcpu, state)
      end)
    },
    step_program = {
      on_gui_click = mixPlayerData(function(player_data)
        local state = Entity.get_data(player_data.current_fcpu)
        player_data.current_fcpu_gui.outer.error_message.caption = ""
        Controller.compile(state)
        Controller.step(state)
        Entity.set_data(player_data.current_fcpu, state)
      end)
    },
    copy_program = {
      on_gui_click = mixPlayerData(function(player_data)
        player_data.program_clipboard = player_data.current_fcpu_gui.outer.inner['program-input'].text
      end)
    },
    paste_program = {
      on_gui_click = mixPlayerData(function(player_data)
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

local function CreateWidget(player)
  local rootGui = player.gui.screen -- mod_gui.get_frame_flow({gui={left=player.gui.screen}})
  if rootGui["fcpu-widget"] then
    rootGui["fcpu-widget"].destroy()
  end

  local memslots = {}
  for i = 1, MC_REGS do
    table.insert(memslots, gui.templates.slot_button('reg'..i))
  end

  local elems = gui.build(rootGui, {
    {type="frame", save_as="gui_fcpu", name="fcpu-widget", style="inner_frame_in_outer_frame", direction="vertical", children={
      {type="flow", name="titlebar", children={
        {template="frame_title", name="label", caption="fCPU"},
        {template="drag_handle", name="drag_handle"},
        {template="close_button", save_as="gui_exit_button", handlers="widget.close_button"},
      }},

      {type="frame", name="outer", style="inside_shallow_frame_with_padding", direction="vertical", children={
        {type="flow", name="buttons_row", direction="horizontal", style_mods={vertical_align="center"}, children={
          gui.templates.control_button("halt", "stop", "red"),
          gui.templates.control_button("run", "play", "green"),
          gui.templates.control_button("step", "next"),
          --{template="pushers.horizontal"},
          --gui.templates.control_button("copy", "copy"),
          --gui.templates.control_button("paste", "paste"),
          {template="pushers.horizontal"},
          {type="switch", style_mods={ right_margin=10 }, left_label_caption={"gui-constant.off"}, right_label_caption={"gui-constant.on"}, save_as="gui_enable_switch", handlers="widget.enable_program"},
        }},
        {template="heading_2", caption={"gui-fcpu.registers"}},
        {type="flow", save_as="gui_inspector", direction="horizontal",
          children={
            table.unpack(memslots)
          },
          style_mods={horizontally_stretchable=true, horizontal_align="center"},
        },
        {template="heading_2", caption={"gui-fcpu.program"}},
        {type="scroll-pane", style_mods={maximal_height=490}, horizontal_scroll_policy="never", children={
          {type="flow", name="inner", direction="horizontal",
            children={
              {type="text-box", style="fcpu_notice_textbox", save_as="gui_line_numbers",
                ignored_by_interaction=true,
              },
              {type="text-box", name="program-input", style="fcpu_program_input",
                style_mods={
                  vertically_stretchable=false,
                  horizontally_stretchable=true,
                  rich_text_setting=defines.rich_text_setting.enabled
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
        {type="label", name="error_message", caption="", style="bold_red_label", style_mods={
          top_margin=10,
          horizontally_stretchable=true,
          horizontally_squashable=true,
          single_line=false,
        }},
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

function GuiWidgetOpen(player, entity)
  local player_data = get_player_data(player.index)
  local state = Entity.get_data(entity)

  local elems = CreateWidget(player)
  if 0 < fcpu_debug_enabled then
    elems.gui_fcpu.titlebar.label.caption = elems.gui_fcpu.titlebar.label.caption.." #"..entity.unit_number
  end
  state = table.merge(state, elems)

  state.gui_program_input.text = state.program_text
  GuiWidgetUpdate(state)

  if state.error_message then
    state.gui_fcpu.outer.error_message.caption = state.error_message
  end

  if state.disabled then
    state.gui_enable_switch.switch_state = "left"
  else
    state.gui_enable_switch.switch_state = "right"
  end

  if Controller.is_running(state) then
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

local function UpdateLines(element, state)
  local lines = {}
  for i = 1, MC_LINES do
    local line = tostring(i)
    if i < 10 then line = " "..i end
    if i == state.error_line then
      line = line..'!'
    elseif i == state.instruction_pointer then
      line = line..'>'
    else
      line = line..' '
    end
    table.insert(lines, line)
  end
  element.text = table.concat(lines, "\n")
end

function GuiWidgetUpdate(state)
  -- Enable/Disable the run/step button
  if state.gui_run_button and state.gui_run_button.valid then
    if Controller.is_running(state) then
      --state.gui_halt_button.style = "highlighted_tool_button"
      state.gui_halt_button.sprite = "fcpu-pause-sprite"
      state.gui_halt_button.enabled = true
      state.gui_run_button.enabled = false
    else
      --state.gui_halt_button.style = "tool_button_red"
      state.gui_halt_button.sprite = "fcpu-stop-sprite"
      state.gui_halt_button.enabled = (state.instruction_pointer ~= 1)
      state.gui_run_button.enabled = true
    end
  end
  -- Make text read-only while running
  if state.gui_program_input and state.gui_program_input.valid then
    state.gui_program_input.read_only = Controller.is_running(state)
  end
  -- Update the program lines in the GUI
  if state.gui_line_numbers and state.gui_line_numbers.valid then
    UpdateLines(state.gui_line_numbers, state)
  end
  -- Update the inspector GUI
  if state.gui_inspector and state.gui_inspector.valid and state.regs then
    for i = 1, MC_REGS do
      local reg = state.regs[i]
      if reg then
        local button = state.gui_inspector['reg'..i..'-inspect']
        button.sprite = signalToSpritePath(reg.signal)
        if reg.fixedpoint then
          button.number = reg.count / MC_FIXEDPOINT
        else
          button.number = reg.count
        end
      end
    end
  end
end

function GuiWidgetClose(player_index, silent)
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

function GuiEntityCloseWidget(entity)
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

      GuiWidgetOpen(player, entity)
    end
  elseif entity then
    GuiWidgetClose(event.player_index)
  end
end)

-- Handle fCPU GUI Close event.
script.on_event("fcpu-close", function(event)
  GuiWidgetClose(event.player_index)
end)

-- Handle player move event to close GUI when out of range.
script.on_event(defines.events.on_player_changed_position, function(event)
  local player_data, player = get_player_data(event.player_index)
  if player_data and player_data.current_fcpu and player_data.current_fcpu_gui then
    if not player.can_reach_entity(player_data.current_fcpu) then
      GuiWidgetClose(event.player_index, true)
    end
  end
end)


script.on_event(defines.events.on_runtime_mod_setting_changed, UpdateModSetting)


-------------------------------------------------------------------------------------------------------
local migration = require("__flib__.migration")
local migrations = require("src/migrations.lua")

script.on_init(function()
  gui.init()
  gui.build_lookup_tables()
  global.fcpus = {}
end)
script.on_load(function()
  gui.build_lookup_tables()
end)
script.on_configuration_changed(function(e)
  if migration.on_config_changed(e, migrations) then
    gui.check_filter_validity()
  end
end)
