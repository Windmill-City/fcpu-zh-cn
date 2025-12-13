local MainView = {}

local gui
local MemoryView

local defaultToolbarInsertSignal = {type='virtual', name='signal-dot'}
local fcpu_gui_editor_width = 290

-------------------------------------------------------------------------------------------------------

local function inplace_dictionary_combine(dst, ...)
  local tables = {...}
  --local new = {}
  for _, tab in pairs(tables) do
      for k, v in pairs(tab) do
        dst[k] = v
      end
  end
  --return new
end

local function string_insert(str1, str2, pos)
  return str1:sub(1,pos)..str2..str1:sub(pos+1)
end

local function InsertTextInProgram(player_data, signal_str)
  if not signal_str then
    return
  end
  -- see: https://forums.factorio.com/viewtopic.php?f=28&t=88330
  local pos = player_data.gui_program_input.text:len()
  player_data.gui_program_input.text = string_insert(player_data.gui_program_input.text, signal_str, pos)
  fcpu_update_program(player_data.current_fcpu, player_data.gui_program_input.text)
end

local function FormatBreakpointTitle(state, i)
  local line = tostring(i)
  if i < 10 then line = "  "..i elseif i < 100 then line = " "..i end
  line = '[font=fcpu-mono]'..line..'[/font]'

  if not state then
    return ' '.. line ..' '
  end

  if i == state.instruction_pointer then
    line = '[color=blue]'..line..'➧[/color]'
  elseif i == state.error_line then
    line = '[color=1,0.4,0.4]'..line..'⚠[/color]'
  else
    line = line..' '
  end

  if state.breakpoints[i] then
    --line = '[img=fcpu-breakpoint-on]'.. line
    line = '[color=1,0.4,0.4]●[/color]'..line
  else
    --line = '[img=fcpu-breakpoint-empty]'.. line
    line = ' '..line
  end

  return line
end

-------------------------------------------------------------------------------------------------------

function MainView.RegisterTemplates()
  gui.add_templates{
    frame_title = {type="label", style="frame_title"},
    frame_action_button = {type="sprite-button", style="frame_action_button", mouse_button_filter={"left"}},
    frame_action_checkbox = {type="checkbox", style="frame_action_button", mouse_button_filter={"left"}},
    drag_handle = {type="empty-widget", name="drag-handle", style="draggable_space_header", style_mods={minimal_width=30, height=24, right_margin=4, horizontally_stretchable=true}},
    pin_button = {template="frame_action_button", sprite="fcpu-pin-white", hovered_sprite="fcpu-pin-black"},
    close_button = {type="sprite-button", style="close_button", sprite="utility/close"},

    pushers = {
      horizontal = {type="empty-widget", style_mods={horizontally_stretchable=true}},
      vertical = {type="empty-widget", style_mods={vertically_stretchable=true}}
    },

    control_button = function(name, sprite, color, handler)
      return {type="sprite-button", style="tool_button"..(color and "_"..color or ""), name=name.."-program", sprite="fcpu-"..sprite.."-sprite", save_as="gui_"..name.."_button", tooltip={"gui-fcpu."..name.."-program"}, handlers="widget."..(handler or name.."_program")}
    end,
    tool_button = function(name, sprite, color, ...)
      return table.deep_merge{{type="sprite-button", style="shortcut_bar_button_small"..(color and "_"..color or ""), name=name.."-program", sprite="fcpu-"..sprite.."-sprite", handlers="widget."..name.."_program"}, ...}
    end,

    heading_2 = {type="label", style="caption_label", style_mods={padding=4}},
    heading_3 = {type="label", style="semibold_label", style_mods={padding=4}},
    slot_button = function(name, title)
      return {type="sprite-button", style="slot_button_in_shallow_frame", name=name.."-inspect", tooltip=(title or name), handlers="widget.insert_register_to_program"}
    end,
    channel_cell = function(name, ...)
      return table.deep_merge{{type="sprite-button", style="fcpu_channel_cell", name=name .."-inspect"}, ...}
    end,
    breakpoints_button = function(state, num)
      return {type="label", name="break-"..num, caption=FormatBreakpointTitle(state, num),
        style="fcpu_breakpoint_label",
        tooltip={'gui-fcpu.breakpoint-toggle'},
        handlers="widget.breakpoint",
        style_mods={
          minimal_width=42,
          maximal_width=52,
          height=16.5,
        }
      }
    end,
  }
end

-------------------------------------------------------------------------------------------------------

local function CreateWidget_Main(rootGui)
  -- Update settings value
  fcpu_gui_editor_width = settings.get_player_settings(rootGui.player_index)["fcpu-gui-editor-width"].value

  local regslots = {}
  for i = 1, MC_REGS do
    table.insert(regslots, gui.templates.slot_button('reg'..i))
  end

  local breakpoints = {}
  for i = 1, MC_LINES do
    table.insert(breakpoints, gui.templates.breakpoints_button(nil, i))
  end

  local elems = gui.build(rootGui, {
    {type="frame", save_as="gui_fcpu", name="fcpu-widget", style="frame", direction="vertical", children={
      {type="flow", name="titlebar", children={
        {template="frame_action_button", name="rename-button", handlers="widget.rename_button", sprite="utility/rename_icon", hovered_sprite="utility/rename_icon"},
        {type="textfield", name="custom-name", handlers="widget.rename_field", style="search_popup_textfield", visible=false, clear_and_focus_on_right_click=true, style_mods={ bottom_margin=2 }},
        {template="frame_title", name="label", style_mods={maximal_width=fcpu_gui_editor_width-50}},
        {template="drag_handle", name="drag-handle"},
        {template="pin_button", save_as="gui_pin_button", handlers="widget.pin_button", state=false},
        {template="close_button", save_as="gui_exit_button", handlers="widget.close_button"},
      }},
      {type="flow", name="fcpu-panels", direction="horizontal", style_mods={maximal_height=710, horizontal_spacing=12}, children={

        {type="frame", name="fcpu-main", style="inside_shallow_frame_with_padding", direction="vertical", children={
          -- Control buttons
          {type="flow", name="buttons-row", direction="horizontal", style_mods={vertical_align="center"}, children={
            gui.templates.control_button("halt", "stop", "red"),
            gui.templates.control_button("run", "play", "green"),
            gui.templates.control_button("step", "next"),
            {template="pushers.horizontal"},
            {type="switch", left_label_caption={"gui-constant.off"}, right_label_caption={"gui-constant.on"}, save_as="gui_enable_switch", handlers="widget.enable_program"},
            {template="pushers.horizontal"},
            gui.templates.control_button("memory", "memory", "blue", "view_memory"),
          }},

          -- Registers inspector
          {template="heading_2", caption={"gui-fcpu.registers"}},
          {type="flow", save_as="gui_inspector", direction="horizontal",
            children={
              table.unpack(regslots)
            },
            style_mods={horizontally_stretchable=true, horizontal_align="center"},
          },

          -- Editor toolbar
          {type="flow", save_as="gui_editor_toolbar", name="editor-toolbar", direction="horizontal",
            children={
              {template="heading_2", caption={"gui-fcpu.program"}},
              {template="pushers.horizontal"},

              gui.templates.tool_button("copy", "copy", "green", {tooltip={"gui-fcpu.copy-program"}, style="fcpu_toolbar_copy"}),
              gui.templates.tool_button("paste", "paste", "", {tooltip={"gui-fcpu.paste-program"}, style="fcpu_toolbar_paste"}),

              {template="pushers.horizontal", style_mods={width=16}},
              {
                type="choose-elem-button",
                elem_type="signal",
                style="shortcut_bar_button_small",
                name="insert-signal-to-program",
                tooltip={"gui-fcpu.insert-signal-to-program"},
                handlers="widget.insert_signal_to_program",
              },
            },
            style_mods={horizontally_stretchable=true, horizontal_align="right", vertical_align="center", top_margin=8},
          },

          -- Editor
          {type="scroll-pane", save_as="gui_scroll_panel", horizontal_scroll_policy="auto", style="scroll_pane_in_shallow_frame", children={
            {type="flow", name="inner", direction="horizontal",
              children={
                {type="flow", name="inner", save_as="gui_breakpoints", direction="vertical",
                  style_mods={
                    width = 44,
                    height = 20 * MC_LINES,
                    horizontally_stretchable=true,
                    top_padding=4,
                  },
                  children={
                    table.unpack(breakpoints)
                  }
                },
                {type="text-box", name="program-input", style="fcpu_program_input",
                  style_mods={
                    width = fcpu_gui_editor_width,
                    height = 20 * MC_LINES + 21, -- + 2568 * 2 + 5,
                    vertically_stretchable=false,
                    rich_text_setting=defines.rich_text_setting.enabled
                  },
                  horizontal_scroll_policy="never",
                  vertical_scroll_policy="never",
                  handlers="widget.program_input",
                  save_as="gui_program_input",
                  icon_selector = true,
                },
              },
              horizontal_scroll_policy="auto",
              style_mods={
                width = fcpu_gui_editor_width,
                height = 20 * MC_LINES + 20,
                horizontally_squashable=true,
                horizontally_stretchable=true,
                vertically_squashable=true,
              },
            },
          }},

          -- Error message
          {type="label", name="error_message", save_as="gui_error_message", caption="", style="label", style_mods={
            top_margin=10,
            horizontally_stretchable=true,
            horizontally_squashable=true,
            single_line=false,
            font_color={1,0.4,0.4}
          }},
        }},

      }},
      {type="flow", name="footer", children={
      }},
    }}
  })

  elems.gui_editor_toolbar['insert-signal-to-program'].elem_value = defaultToolbarInsertSignal
  elems.gui_fcpu.titlebar['label'].drag_target = elems.gui_fcpu
  elems.gui_fcpu.titlebar['drag-handle'].drag_target = elems.gui_fcpu

  return elems
end

local function GuiWidgetUpdateTitle(player_data, state)
  local title = state.custom_name or "fCPU"
  if 0 < fcpu_debug_enabled then
    player_data.gui_fcpu.titlebar.label.caption = title .." #".. state.entity.unit_number ..' ⇨ '.. state.index
  else
    player_data.gui_fcpu.titlebar.label.caption = title
  end
end

local function GuiWidgetUpdatePinButton(player, force)
  local player_data = get_player_data(player.index)
  if player_data.gui_pin_button and player_data.gui_pin_button.valid then
    if player_data.gui_pinned then
      player_data.gui_pin_button.style = "flib_selected_frame_action_button"
      player_data.gui_fcpu.auto_center = false
      player_data.gui_pinned_location = player_data.gui_fcpu.location
      player.opened = nil
    else
      player_data.gui_pin_button.style = "frame_action_button"
      if force then
        player_data.gui_fcpu.force_auto_center()
      end
      player.opened = player_data.gui_fcpu
    end
  end
end

local function GuiWidgetVisible(player, player_data, visible)
  visible = visible or (visible == false and nil)
  if visible then
    if not (player_data.gui_fcpu and player_data.gui_fcpu.valid) then
      local rootGui = player.gui.screen
      local elems = CreateWidget_Main(rootGui)
      inplace_dictionary_combine(
        player_data,
        elems,
        player_data.gui_pinned and player_data.gui_pinned_memory and MemoryView.CreateWidget(elems.gui_fcpu["fcpu-panels"]) or {}
      )
    end
    player_data.gui_fcpu.visible = true
  elseif visible == false then
    player_data.gui_fcpu.visible = false
  else
    local rootGui = player.gui.screen
    player_data.gui_fcpu = nil
    rootGui["fcpu-widget"].destroy()
  end
end

function GuiWidgetIsVisible(player_data)
  return player_data.gui_fcpu and player_data.gui_fcpu.valid and player_data.gui_fcpu.visible
end

function GuiWidgetOpen(player, entity)
  local player_data = get_player_data(player.index)
  local state = get_fcpu_state(entity)

  local rootGui = player.gui.screen -- mod_gui.get_frame_flow({gui={left=player.gui.screen}})
  if rootGui["fcpu-widget"] then
    if player_data.gui_pinned then
      if player_data.gui_fcpu and player_data.gui_fcpu.valid then
        player_data.gui_pinned_location = player_data.gui_fcpu.location
      end
    end
    GuiWidgetVisible(player, player_data, false)
  end
  if not state then
    return
  end

  GuiWidgetVisible(player, player_data, true)
  if player_data.gui_pinned then
    if player_data.gui_fcpu and player_data.gui_fcpu.valid then
      player_data.gui_fcpu.location = player_data.gui_pinned_location
    end
  end

  GuiWidgetUpdateTitle(player_data, state)
  GuiWidgetUpdatePinButton(player, true)
  GuiWidgetUpdate(player_data, state, true)

  player_data.gui_program_input.text = state.program_text
  if fcpu_gui_editor_inline_icons then
    player_data.gui_program_input.style.rich_text_setting = defines.rich_text_setting.enabled
  else
    player_data.gui_program_input.style.rich_text_setting = defines.rich_text_setting.disabled
  end

  if state.error_message then
    player_data.gui_error_message.caption = state.error_message
  end

  if state.disabled then
    player_data.gui_enable_switch.switch_state = "left"
  else
    player_data.gui_enable_switch.switch_state = "right"
  end

  if Controller.is_running(state) then
    player_data.gui_run_button.enabled = false
  else
    player_data.gui_run_button.enabled = true
  end

  player.play_sound{path="entity-open/"..entity.prototype.name, volume_modifier=0.85}

  player_data.current_fcpu = entity
  player_data.gui_fcpu = player_data.gui_fcpu
end

local function UpdateWidget_Breakpoints(player_data, state, initial)
  local gui_cache = state.gui_cache
  if gui_cache then
    local gui_elements = player_data.gui_breakpoints.children
    local update_line = function(i)
      local line = gui_elements[i]
      if line then
        line.caption = FormatBreakpointTitle(state, i)
      end
    end
    if initial or gui_cache.invalid_lines == nil then
      for i = 1,MC_LINES do
        update_line(i)
      end
    else
      for k,_ in pairs(gui_cache.invalid_lines) do
        update_line(k)
      end
    end
    gui_cache.invalid_lines = {}
  end
end

function GuiWidgetUpdate(player_data, state, initial)
  local isRunning = Controller.is_running(state)

  -- Enable/Disable the run/step button
  if player_data.gui_run_button and player_data.gui_run_button.valid then
    if isRunning then
      --player_data.gui_halt_button.style = "highlighted_tool_button"
      player_data.gui_halt_button.sprite = "fcpu-pause-sprite"
      player_data.gui_halt_button.tooltip = {"gui-fcpu.halt-program"}
      player_data.gui_halt_button.enabled = true
      player_data.gui_run_button.enabled = false
      player_data.gui_inspector.ignored_by_interaction = true
    else
      --player_data.gui_halt_button.style = "tool_button_red"
      player_data.gui_halt_button.sprite = "fcpu-stop-sprite"
      player_data.gui_halt_button.tooltip = {"gui-fcpu.reset-program"}
      player_data.gui_halt_button.enabled = not Controller.is_first_instruction(state)
      player_data.gui_run_button.enabled = not Controller.is_error(state)
      player_data.gui_inspector.ignored_by_interaction = false
    end
    player_data.gui_step_button.enabled = not Controller.is_error(state)
  end
  -- Update the inspector GUI
  if player_data.gui_inspector and player_data.gui_inspector.valid and state.regs then
    for i = 1, MC_REGS do
      local reg = state.regs[i]
      if reg then
        local button = player_data.gui_inspector['reg'..i..'-inspect']
        button.sprite = GUI_signalToSpritePath(player_data, reg.signal)
        button.quality = reg.signal and reg.signal.name and reg.signal.quality
        button.number = reg.count
        if isRunning then
          button.tooltip = 'r'..i
        else
          button.tooltip = GUI_signalToTooltip(reg, 'r'..i)
        end
      end
    end
  end
  -- Update toolbar
  if player_data.gui_fcpu and player_data.gui_fcpu.valid then
    local toolbar = player_data.gui_editor_toolbar
    if toolbar then
      local button_istp = toolbar['insert-signal-to-program']
      if button_istp and button_istp.valid then
        button_istp.enabled = not isRunning
      end
      local button_paste = toolbar['paste-program']
      if button_paste and button_paste.valid then
        button_paste.enabled = not isRunning
      end
    end
  end
  -- Make text read-only while running
  if player_data.gui_program_input and player_data.gui_program_input.valid then
    player_data.gui_program_input.read_only = isRunning
  end
  -- Update the program lines in the GUI
  if player_data.gui_breakpoints and player_data.gui_breakpoints.valid then
    UpdateWidget_Breakpoints(player_data, state, initial)
  end

  if player_data.gui_memory_view and player_data.gui_memory_view.valid then
    MemoryView.UpdateWidget(player_data, state, initial)
  end
end

function GuiWidgetClose(player_index, skip_if_pinned, silent)
  local player_data, player = get_player_data(player_index)
  if player_data and player_data.current_fcpu then
    if skip_if_pinned and player_data.gui_pinned then
      return
    end
    if not (player_data.gui_fcpu and player_data.gui_fcpu.valid) then
      local rootGui = player.gui.screen -- mod_gui.get_frame_flow({gui={left=player.gui.screen}})
      if rootGui["fcpu-widget"] then
        rootGui["fcpu-widget"].destroy()
      end
      return
    end

    if player_data.current_fcpu.valid then
      fcpu_update_program(player_data.current_fcpu, player_data.gui_program_input.text)
      player_data.current_fcpu.operable = true

      if not silent then
        player.play_sound{path="entity-close/"..player_data.current_fcpu.prototype.name, volume_modifier=0.85}
      end
    end

    if player_data.gui_pinned then
      player_data.gui_pinned_location = player_data.gui_fcpu.location
    end
    GuiWidgetVisible(player, player_data, false)
    player_data.current_fcpu = nil
  end
end

function GuiEntityCloseWidget(unit_number, force_destroy)
  for player_index, player in pairs(game.players) do
    local player_data = get_player_data(player_index)
    if not (player_data.current_fcpu and player_data.current_fcpu.valid)
    or player_data.current_fcpu.unit_number == unit_number
    or unit_number == nil
    then
      if player_data.gui_fcpu and player_data.gui_fcpu.valid then
        if player_data.gui_pinned then
          player_data.gui_pinned_location = player_data.gui_fcpu.location
        end
        if force_destroy then
          GuiWidgetVisible(player, player_data, nil)
        else
          GuiWidgetVisible(player, player_data, false)
        end
      end
      player_data.current_fcpu = nil
      player_data.current_gui_cache = nil
    end
  end
end

-------------------------------------------------------------------------------------------------------

function MainView.RegisterHandlers(ControlHandlers)
  gui.add_handlers{
    widget = {
      rename_button = {
        on_gui_click = GUI_mixPlayerData(function(player_data, state, event, player)
          local titlebar = player_data.gui_fcpu.titlebar
          if titlebar['custom-name'].visible then
            titlebar['label'].visible = true
            titlebar['custom-name'].visible = false
            titlebar['rename-button'].style = "frame_action_button"
          else
            titlebar['label'].visible = false
            titlebar['custom-name'].text = state.custom_name or ''
            titlebar['custom-name'].visible = true
            titlebar['custom-name'].focus()
            titlebar['rename-button'].style = "flib_selected_frame_action_button"
          end
        end)
      },
      rename_field = {
        on_gui_confirmed = GUI_mixPlayerData(function(player_data, state, event)
          local titlebar = player_data.gui_fcpu.titlebar
          titlebar['label'].visible = true
          titlebar['custom-name'].visible = false
          titlebar['rename-button'].style = "frame_action_button"

          state.custom_name = string.gsub(event.element.text, [[^%s*(.-)%s*$]], '%1')
          if #state.custom_name == 0 then
            state.custom_name = nil
          end
          GuiWidgetUpdateTitle(player_data, state)
        end)
      },
      pin_button = {
        on_gui_click = GUI_mixPlayerData(function(player_data, state, event, player)
          player_data.gui_pinned = not player_data.gui_pinned
          GuiWidgetUpdatePinButton(player)
        end)
      },
      close_button = {
        on_gui_click = function(event)
          GuiWidgetClose(event.player_index)
        end
      },
      program_input = {
        on_gui_text_changed = GUI_mixPlayerData(function(player_data, state, event)
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
          fcpu_update_program(state.entity, element.text)
        end)
      },
      enable_program = {
        on_gui_switch_state_changed = GUI_mixPlayerData(function(player_data, state, event)
          if event.element then
            if event.element.switch_state == "right" then
              Controller.disable(state, false)
              if not Controller.is_running(state) and Controller.is_first_instruction(state) then
                player_data.gui_error_message.caption = ""
                Controller.compile(state)
                Controller.run(state)
              end
            else
              Controller.disable(state)
            end
          end
        end)
      },
      run_program = {
        on_gui_click = ControlHandlers['fcpu-debug-start']
      },
      halt_program = {
        on_gui_click = GUI_mixPlayerData(function(player_data, state, event)
          if Controller.is_running(state) then
            ControlHandlers['fcpu-debug-pause'](event)
          elseif Controller.is_error(state) then
            ControlHandlers['fcpu-debug-reset'](event)
          else
            ControlHandlers['fcpu-debug-stop'](event)
          end
        end)
      },
      step_program = {
        on_gui_click = ControlHandlers['fcpu-debug-step-over']
      },
      copy_program = {
        on_gui_click = GUI_mixPlayerData(function(player_data)
          if player_data.gui_program_input then
            player_data.program_clipboard = player_data.gui_program_input.text
          end
        end)
      },
      paste_program = {
        on_gui_click = GUI_mixPlayerData(function(player_data, state)
          if player_data.gui_program_input and player_data.program_clipboard then
            player_data.gui_program_input.text = player_data.program_clipboard
            fcpu_update_program(state.entity, player_data.gui_program_input.text)
          end
        end)
      },
      insert_signal_to_program = {
        on_gui_elem_changed = GUI_mixPlayerData(function(player_data, state, event)
          local signal = event.element.elem_value
          if signal then
            local signal_str = signalToStr(signal)
            event.element.elem_value = defaultToolbarInsertSignal
            InsertTextInProgram(player_data, signal_str)
          end
        end)
      },
      insert_register_to_program = {
        on_gui_click = GUI_mixPlayerData(function(player_data, state, event)
          local k, v = string.match(event.element.tooltip, '([^=]+)=(.+)')
          if event.button == defines.mouse_button_type.left then
            InsertTextInProgram(player_data, k)
          else
            InsertTextInProgram(player_data, v)
          end
        end)
      },
      view_memory = {
        on_gui_click = GUI_mixPlayerData(function(player_data, state)
          if player_data.gui_fcpu and player_data.gui_fcpu["fcpu-panels"] then
            local rootGui = player_data.gui_fcpu["fcpu-panels"]
            if rootGui["fcpu-memory-view"] then
              player_data.gui_pinned_memory = false
              MemoryView.DestroyWidget(player_data)
            else
              player_data.gui_pinned_memory = true
              local elems = MemoryView.CreateWidget(rootGui)
              inplace_dictionary_combine(player_data, elems)
              MemoryView.UpdateWidget(player_data, state, true)
            end
          end
        end)
      },
      breakpoint = {
        on_gui_click = GUI_mixPlayerData(function(player_data, state, event)
          if player_data.gui_breakpoints and event.element then
            local num = tonumber(string.match(event.element.name, 'break%-(%d+)$'))
            if num then
              state.breakpoints[num] = not state.breakpoints[num] or nil;
              event.element.caption = FormatBreakpointTitle(state, num)
            end
          end
        end)
      },
    }
  }
end

-------------------------------------------------------------------------------------------------------

function MainView.setup(gui_, memoryview_, handlers)
  gui = gui_
  MemoryView = memoryview_
  MainView.RegisterTemplates()
  MainView.RegisterHandlers(handlers)
end
return MainView
