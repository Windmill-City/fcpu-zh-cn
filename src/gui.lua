-- require('mod-gui')

local gui = require("__flib__.gui")

local defaultToolbarInsertSignal = {type='virtual', name='signal-dot'}

local function signalToSpritePath(player_data, signal)
  if signal then
    local path
    if signal.type == "virtual" then
      path = "virtual-signal/" .. signal.name
    elseif signal.name then
      path = signal.type .. '/' .. signal.name
    end
    if path and (player_data and player_data.gui_fcpu and player_data.gui_fcpu.gui) then
      if player_data.gui_fcpu.gui.is_valid_sprite_path(path) then
        return path
      end
    end
  end
end

local function signalToTooltip(signal, prefix)
  local str = signal.count or ''
  if signal.signal then
    if signal.signal.type == 'virtual' then
      str = str .. '[virtual-signal='.. signal.signal.name ..']'
    else
      str = str .. '['.. signal.signal.type ..'='.. signal.signal.name ..']'
    end
  end
  if prefix then
    return prefix .. (str and ('='.. str) or '')
  else
    return (str or '')
  end
end

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

local function InsertTextInProgram(player_data, signal_str)
  -- see: https://forums.factorio.com/viewtopic.php?f=28&t=88330
  local pos = player_data.gui_program_input.text:len()
  player_data.gui_program_input.text = string.insert(player_data.gui_program_input.text, signal_str, pos)
  fcpu_update_program(player_data.current_fcpu, player_data.gui_program_input.text)
end

local function FormatBreakpointTitle(state, i)
  local line = tostring(i)
  if i < 10 then line = "  "..i elseif i < 100 then line = " "..i end
  line = '[font=fcpu-mono]'..line..'[/font]'

  if state and i == state.error_line then
    line = '[color=1,0.4,0.4]'..line..'⚠[/color]'
  elseif state and i == state.instruction_pointer then
    line = '[color=blue]'..line..'➧[/color]'
  else
    line = line..' '
  end

  if state and state.breakpoints[i] then
    --line = '[img=fcpu-breakpoint-on]'.. line
    line = '[color=1,0.4,0.4]●[/color]'..line
  else
    --line = '[img=fcpu-breakpoint-empty]'.. line
    line = ' '..line
  end

  return line
end

-------------------------------------------------------------------------------------------------------

gui.add_templates{
  frame_title = {type="label", style="frame_title"},
  frame_action_button = {type="sprite-button", style="frame_action_button", mouse_button_filter={"left"}},
  drag_handle = {type="empty-widget", name="drag-handle", style="draggable_space_header", style_mods={minimal_width=30, height=24, right_margin=4, horizontally_stretchable=true}},
  close_button = {template="frame_action_button", sprite="utility/close_white", hovered_sprite="utility/close_black"},

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

  heading_2 = {type="frame", style="invisible_frame_with_title"},
  heading_3 = {type="label", style="heading_3_label", style_mods={padding=4}},
  slot_button = function(name, title)
    return {type="sprite-button", style="slot_button_in_shallow_frame", name=name.."-inspect", tooltip=(title or name), handlers="widget.insert_register_to_program"}
  end,
  slot_inventory = function(name, title, ...)
    return table.deep_merge{{type="sprite-button", style="inventory_slot", name=name .."-inspect", tooltip=(title or name)}, ...}
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

-------------------------------------------------------------------------------------------------------

local function CreateWidget_MemoryView(rootGui)
  local memchannels = {}
  for i = 1, MC_MEMORY_CHANNELS do
    memchannels[#memchannels + 1] = 'mem'.. i
  end
  memchannels[#memchannels+1] = { 'gui-fcpu-memviewer.channel-registers' }
  memchannels[#memchannels+1] = { 'gui-fcpu-memviewer.channel-input-red' }
  memchannels[#memchannels+1] = { 'gui-fcpu-memviewer.channel-input-green' }
  memchannels[#memchannels+1] = { 'gui-fcpu-memviewer.channel-output-scalar' }
  memchannels[#memchannels+1] = { 'gui-fcpu-memviewer.channel-output-vector' }
  memchannels[#memchannels+1] = { 'gui-fcpu-memviewer.channel-output' }

  local elems = gui.build(rootGui, {
    {type="frame", name="fcpu-memory-view", save_as="gui_memory_view", style="inside_shallow_frame_with_padding", direction="vertical", children={
      {template="heading_3", caption={"gui-fcpu-memviewer.memory-channel"}},
      {type='drop-down', save_as='gui_memory_channel', items={ table.unpack(memchannels) }, selected_index=1, handlers="memory.memory_channel"},

      {template="heading_3", caption={"gui-fcpu-memviewer.memory-view"}},
      {type="scroll-pane", style="scroll_pane_in_shallow_frame", direction="vertical", children={
        {type="table", save_as="gui_memory_cells", style="slot_table", column_count=8 --[[ will be populated in `MemoryView_UpdateFromTable` ]]},
      }}
    }}
  });

  return elems
end

local function DestroyWidget_MemoryView(player_data)
  if not player_data or not player_data.gui_fcpu or not player_data.gui_fcpu["fcpu-panels"] or not player_data.gui_fcpu["fcpu-panels"]["fcpu-memory-view"] then
    return
  end

  player_data.gui_fcpu["fcpu-panels"]["fcpu-memory-view"].destroy()
  player_data.gui_memory_view = nil
  player_data.gui_memory_cells = nil
end

local function MemoryView_UpdateFromTable(player_data, signals, sort, sparse, order)
  local cells = player_data.gui_memory_cells.children
  if cells then
    --[[if order ~= nil then
      -- TODO: order is different than in Factorio
      local t = {}
      for _,v in ipairs(signals) do
        t[v.signal.type..'='..v.signal.name] = v
      end
      local n = {}
      for k,v in ipairs(order) do
        local s = t[v.signal.type..'='..v.signal.name]
        if s then
          n[k] = s
          t[v.signal.type..'='..v.signal.name] = nil
        else
          n[k] = NULL_SIGNAL
        end
      end
      for _,v in pairs(t) do
        n[#n+1] = v
      end
      signals = n
    end]]

    -- add extra
    for i = #cells + 1, math.max(MC_MEMORY_SLOTS_MIN, (signals and #signals or 0)) do
      gui.build(player_data.gui_memory_cells, { gui.templates.slot_inventory('index-'..i, '['..i..']', {visible=false}) })
    end
    cells = player_data.gui_memory_cells.children

    local i = 1
    -- show and setup visible
    if signals then
      for _, v in ipairs(signals) do
        local cell = cells[i]
        if v and cell then
          local sprite = signalToSpritePath(player_data, v.signal)
          cell.visible = true
          cell.sprite = sprite
          if sort == 0 then
            cell.number = v.count
          else
            cell.number = sprite and v.count or nil
          end
          if sprite or sort then
            i = i + 1
          elseif not sparse then
            break
          end
        end
      end
    end

    -- clear `number`
    while i <= MC_MEMORY_SLOTS_MIN and cells[i] do
      cells[i].visible = true
      cells[i].sprite = nil
      cells[i].number = nil
      i = i + 1
    end

    -- hide others
    while i <= #cells and cells[i] and cells[i].visible do
      cells[i].visible = false
      i = i + 1
    end
  end
end

local function UpdateWidget_MemoryView(player_data, state, initial)
  if not player_data.gui_memory_channel then return end
  local index = player_data.gui_memory_channel.selected_index

  if state then
    index = math.max(1, index)

    local ValidateGuiCache = function(channel)
      player_data.gui_cache = player_data.gui_cache or {}
      if player_data.gui_cache.memory_changed == nil or initial then
        player_data.gui_cache.memory_changed = {}
      end
      if state.gui_cache.memory_changed == nil then
        return false
      end

      local pmc = player_data.gui_cache.memory_changed[channel]
      local smc = state.gui_cache.memory_changed[channel]

      if not (pmc and smc) or (pmc < smc) and (smc <= game.tick) then
        player_data.gui_cache.memory_changed[channel] = smc
        return false
      end
      return true
    end

    if index <= MC_MEMORY_CHANNELS then
      if ValidateGuiCache('mem'..index) then return end
      -- Memory channels
      local ics = state.program_ics['mem' .. index]
      if ics and ics.out and ics.out.valid then
        local control = ics.out.get_control_behavior()
        if control.signals_last_tick then
          local network = control.get_circuit_network(defines.wire_type.red, defines.circuit_connector_id.combinator_output)
          if network then
            MemoryView_UpdateFromTable(player_data, network.signals)
            --MemoryView_UpdateFromTable(player_data, network.signals, 0, true, control.signals_last_tick)
          else
            MemoryView_UpdateFromTable(player_data, control.signals_last_tick)
          end
          return
        else
          if ics.value then
            local vc = ics.value.get_control_behavior()
            if vc.enabled and vc.parameters then
              MemoryView_UpdateFromTable(player_data, vc.parameters.parameters, 1)
              return
            end
          end

          local network = control.get_circuit_network(defines.wire_type.red, defines.circuit_connector_id.combinator_output)
          if network then
            MemoryView_UpdateFromTable(player_data, network.signals)
            return
          end
        end
      end
    elseif index == MC_MEMORY_CHANNELS + 1 then
      -- Registers
      MemoryView_UpdateFromTable(player_data, state.regs, 0, true)
      return
    elseif index == MC_MEMORY_CHANNELS + 2 then
      -- Input wires (RED)
      local control = state.entity.get_control_behavior()
      local input = control.get_circuit_network(defines.wire_type.red, defines.circuit_connector_id.combinator_input)
      MemoryView_UpdateFromTable(player_data, input and input.signals)
      return
    elseif index == MC_MEMORY_CHANNELS + 3 then
      -- Input wires (GREEN)
      local control = state.entity.get_control_behavior()
      local input = control.get_circuit_network(defines.wire_type.green, defines.circuit_connector_id.combinator_input)
      MemoryView_UpdateFromTable(player_data, input and input.signals)
      return
    elseif index == MC_MEMORY_CHANNELS + 4 then
      if ValidateGuiCache('output') then return end
      -- Output buffer
      if state.program_ics.output then
        local control = state.program_ics.output.get_control_behavior()
        MemoryView_UpdateFromTable(player_data, control and control.parameters and control.parameters.parameters, 1, true)
        return
      end
    elseif index == MC_MEMORY_CHANNELS + 5 then
      -- Vector output
      if state.ics_stack.output and state.program_ics[state.ics_stack.output] then
        local control = state.program_ics[state.ics_stack.output].out.get_control_behavior()
        MemoryView_UpdateFromTable(player_data, control and control.parameters and control.signals_last_tick)
        return
      end
    elseif index == MC_MEMORY_CHANNELS + 6 then
      -- Output
      if state.program_ics.output then
        local control = state.program_ics.output.get_control_behavior()
        local network = control.get_circuit_network(defines.wire_type.red, defines.circuit_connector_id.constant_combinator)
        if network then
          MemoryView_UpdateFromTable(player_data, network.signals)
          return
        end
      end
    end
  end

  MemoryView_UpdateFromTable(player_data, {})
end

-------------------------------------------------------------------------------------------------------
local function UpdateWidget_Breakpoints(player_data, state, initial)
  if state.gui_cache then
    local update_line = function(i)
      local line = player_data.gui_breakpoints.children[i]
      if line then
        line.caption = FormatBreakpointTitle(state, i)
      end
    end
    if initial or state.gui_cache.invalid_lines == nil then
      for i = 1,MC_LINES do
        update_line(i)
      end
    else
      for k,_ in pairs(state.gui_cache.invalid_lines) do
        update_line(k)
      end
    end
    state.gui_cache.invalid_lines = {}
  end
end

-------------------------------------------------------------------------------------------------------
local function CreateWidget_Main(rootGui)
  local regslots = {}
  for i = 1, MC_REGS do
    table.insert(regslots, gui.templates.slot_button('reg'..i))
  end

  local breakpoints = {}
  for i = 1, MC_LINES do
    table.insert(breakpoints, gui.templates.breakpoints_button(nil, i))
  end

  local elems = gui.build(rootGui, {
    {type="frame", save_as="gui_fcpu", name="fcpu-widget", style="inner_frame_in_outer_frame", direction="vertical", children={
      {type="flow", name="titlebar", children={
        {template="frame_title", name="label", caption="fCPU"},
        {template="drag_handle", name="drag-handle"},
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
            {type="switch", style_mods={ right_margin=10 }, left_label_caption={"gui-constant.off"}, right_label_caption={"gui-constant.on"}, save_as="gui_enable_switch", handlers="widget.enable_program"},
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
          {type="scroll-pane", horizontal_scroll_policy="never", style="scroll_pane_in_shallow_frame", children={
            {type="flow", name="inner", direction="horizontal",
              children={
                {type="flow", name="inner", save_as="gui_breakpoints", direction="vertical",
                  style_mods={
                    minimal_width=44,
                    maximal_width=52,
                    minimal_height = 2568,
                    maximal_height = 2568,
                    horizontally_stretchable=true,
                    top_padding=4,
                  },
                  children={
                    table.unpack(breakpoints)
                  }
                },
                {type="text-box", name="program-input", style="fcpu_program_input",
                  style_mods={
                    minimal_width = 282,
                    maximal_width = 290,
                    minimal_height = 2568,
                    maximal_height = 2568,
                    horizontally_squashable=true,
                    vertically_stretchable=false,
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
  elems.gui_fcpu.titlebar.label.drag_target = elems.gui_fcpu
  elems.gui_fcpu.titlebar['drag-handle'].drag_target = elems.gui_fcpu
  elems.gui_fcpu.force_auto_center()

  return elems
end

function GuiWidgetOpen(player, entity)
  local player_data = get_player_data(player.index)
  local state = get_fcpu_state(entity)

  local rootGui = player.gui.screen -- mod_gui.get_frame_flow({gui={left=player.gui.screen}})
  if rootGui["fcpu-widget"] then
    rootGui["fcpu-widget"].destroy()
  end
  if not state then
    return
  end

  local elems = CreateWidget_Main(rootGui)
  if 0 < fcpu_debug_enabled then
    elems.gui_fcpu.titlebar.label.caption = elems.gui_fcpu.titlebar.label.caption.." #"..entity.unit_number..' ⇨ '..state.index
  end
  inplace_dictionary_combine(
    player_data,
    elems,
    {}--CreateWidget_MemoryView(elems.gui_fcpu["fcpu-panels"])
  )

  player_data.gui_program_input.text = state.program_text
  GuiWidgetUpdate(player_data, state, true)

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

function GuiWidgetUpdate(player_data, state, initial)
  local isRunning = Controller.is_running(state)

  -- Enable/Disable the run/step button
  if player_data.gui_run_button and player_data.gui_run_button.valid then
    if isRunning then
      --player_data.gui_halt_button.style = "highlighted_tool_button"
      player_data.gui_halt_button.sprite = "fcpu-pause-sprite"
      player_data.gui_halt_button.enabled = true
      player_data.gui_run_button.enabled = false
      player_data.gui_inspector.ignored_by_interaction = true
    else
      --player_data.gui_halt_button.style = "tool_button_red"
      player_data.gui_halt_button.sprite = "fcpu-stop-sprite"
      player_data.gui_halt_button.enabled = not Controller.is_first_instruction(state)
      player_data.gui_run_button.enabled = true
      player_data.gui_inspector.ignored_by_interaction = false
    end
  end
  -- Update the inspector GUI
  if player_data.gui_inspector and player_data.gui_inspector.valid and state.regs then
    for i = 1, MC_REGS do
      local reg = state.regs[i]
      if reg then
        local button = player_data.gui_inspector['reg'..i..'-inspect']
        button.sprite = signalToSpritePath(player_data, reg.signal)
        button.number = reg.count
        if isRunning then
          button.tooltip = 'r'..i
        else
          button.tooltip = signalToTooltip(reg, 'r'..i)
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
    UpdateWidget_MemoryView(player_data, state, initial)
  end
end

function GuiWidgetClose(player_index, silent)
  local player_data, player = get_player_data(player_index)
  if player_data and player_data.current_fcpu then
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

    player_data.gui_fcpu.destroy()
    player_data.gui_fcpu = nil
  end
end

function GuiEntityCloseWidget(entity)
  for player_index, player in pairs(game.players) do
    local player_data = get_player_data(player_index)
    if not (player_data.current_fcpu and player_data.current_fcpu.valid)
    or player_data.current_fcpu.unit_number == entity.unit_number
    or entity.valid and Entity._are_equal(entity, player_data.current_fcpu) then
      if player_data.gui_fcpu and player_data.gui_fcpu.valid then
        player_data.gui_fcpu.destroy()
        player_data.gui_fcpu = nil
      end
      player_data.current_fcpu = nil
    end
  end
end

-------------------------------------------------------------------------------------------------------

function string.insert(str1, str2, pos)
  return str1:sub(1,pos)..str2..str1:sub(pos+1)
end

local function mixPlayerData(proc)
  return function(event)
    local player_data, player = get_player_data(event.player_index)
    proc(player_data, player, event)
  end
end

gui.add_handlers{
  memory={
    memory_channel = {
      on_gui_selection_state_changed = mixPlayerData(function(player_data, player, event)
        if player_data.gui_memory_view then
          local state = get_fcpu_state(player_data.current_fcpu)
          UpdateWidget_MemoryView(player_data, state, true)
        end
      end)
    },
  },
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
        local state = get_fcpu_state(player_data.current_fcpu)
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
      on_gui_click = mixPlayerData(function(player_data)
        local state = get_fcpu_state(player_data.current_fcpu)
        player_data.gui_error_message.caption = ""
        Controller.compile(state)
        Controller.run(state)
      end)
    },
    halt_program = {
      on_gui_click = mixPlayerData(function(player_data)
        local state = get_fcpu_state(player_data.current_fcpu)
        Controller.compile(state)
        if not Controller.is_running(state) then
          Controller.set_program_counter(state, 1)
        end
        Controller.halt(state)
      end)
    },
    step_program = {
      on_gui_click = mixPlayerData(function(player_data)
        local state = get_fcpu_state(player_data.current_fcpu)
        player_data.gui_error_message.caption = ""
        Controller.compile(state)
        Controller.step(state)
      end)
    },
    copy_program = {
      on_gui_click = mixPlayerData(function(player_data)
        player_data.program_clipboard = player_data.gui_program_input.text
      end)
    },
    paste_program = {
      on_gui_click = mixPlayerData(function(player_data)
        if player_data.program_clipboard then
          player_data.gui_program_input.text = player_data.program_clipboard
          fcpu_update_program(player_data.current_fcpu, player_data.gui_program_input.text)
        end
      end)
    },
    insert_signal_to_program = {
      on_gui_elem_changed = mixPlayerData(function(player_data, player, event)
        local signal = event.element.elem_value
        if signal then
          if signal.type == 'virtual' then
            signal.type = 'virtual-signal'
          end
          local signal_str = '['.. signal.type ..'='.. signal.name ..']'
          event.element.elem_value = defaultToolbarInsertSignal
          InsertTextInProgram(player_data, signal_str)
        end
      end)
    },
    insert_register_to_program = {
      on_gui_click = mixPlayerData(function(player_data, player, event)
        local k, v = string.match(event.element.tooltip, '([^=]+)=(.+)')
        if event.button == defines.mouse_button_type.left then
          InsertTextInProgram(player_data, k)
        else
          InsertTextInProgram(player_data, v)
        end
      end)
    },
    view_memory = {
      on_gui_click = mixPlayerData(function(player_data, player)
        if not player_data.gui_fcpu or not player_data.gui_fcpu["fcpu-panels"] or player_data.gui_fcpu["fcpu-panels"]["fcpu-memory-view"] then
          DestroyWidget_MemoryView(player_data)
        else
          local rootGui = player_data.gui_fcpu["fcpu-panels"]
          local elems = CreateWidget_MemoryView(rootGui)
          inplace_dictionary_combine(player_data, elems)
          local state = get_fcpu_state(player_data.current_fcpu)
          UpdateWidget_MemoryView(player_data, state, true)
        end
      end)
    },
    breakpoint = {
      on_gui_click = mixPlayerData(function(player_data, player, event)
        if player_data.gui_breakpoints and event.element then
          local num = tonumber(string.match(event.element.name, 'break%-(%d+)$'))
          local state = get_fcpu_state(player_data.current_fcpu)
          state.breakpoints[num] = not state.breakpoints[num] or nil;
          event.element.caption = FormatBreakpointTitle(state, num)
        end
      end)
    },
  }
}

-------------------------------------------------------------------------------------------------------

gui.register_handlers()

-- Close default gui when it will be opened.
script.on_event(defines.events.on_gui_opened, function(event)
  if gui.dispatch_handlers(event) then return end

  local entity = event.entity
  if entity and entity.valid and entity.name == "fcpu" then
    local player_data, player = get_player_data(event.player_index)
    if player_data and player_data.gui_fcpu and player_data.gui_fcpu.valid then
      player.opened = player_data.gui_fcpu
    end
  end
end)

-- Handle fCPU OPEN event.
script.on_event("fcpu-open", function(event)
  local player = game.players[event.player_index]
  local entity = player.selected
  if entity and entity.name == "fcpu" then
    if not (player.cursor_stack and player.cursor_stack.valid_for_read)
    or (player.cursor_stack.name ~= 'red-wire' and player.cursor_stack.name ~= 'green-wire') then
      if player.can_reach_entity(entity) then
        local player_data = get_player_data(event.player_index)

        if player_data.gui_fcpu and player_data.gui_fcpu.valid and Entity._are_equal(player_data.current_fcpu, entity) then return end

        GuiWidgetOpen(player, entity)
      end
    end
  elseif entity then
    GuiWidgetClose(event.player_index)
  end
end)

-- Handle fCPU GUI Close event.
script.on_event("fcpu-close", function(event)
  GuiWidgetClose(event.player_index)
end)
script.on_event("fcpu-escape", function(event)
  GuiWidgetClose(event.player_index)
end)

-- Handle player move event to close GUI when out of range.
script.on_event(defines.events.on_player_changed_position, function(event)
  local player_data, player = get_player_data(event.player_index)
  if player_data and player_data.current_fcpu and player_data.gui_fcpu then
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
  global.running = {}
  global.deffered = Heap.new()
  register_picker_dolly_handler()
  fcpu_wiki_booktorio_init()
end)
script.on_load(function()
  gui.build_lookup_tables()
  register_picker_dolly_handler()
end)
script.on_configuration_changed(function(e)
  if migration.on_config_changed(e, migrations) then
    gui.check_filter_validity()
  end
  fcpu_wiki_booktorio_init()
end)
