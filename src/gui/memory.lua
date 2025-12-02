local gui = require("3rdparty.flib061.gui")
local MemoryView = {}

---

local function ioChannel_GUI_Validate(player_data, state, channel, force)
  local UpdateMinDelay = 0
  local TestImpl = function(force)
    player_data.gui_cache = player_data.gui_cache or {}
    if player_data.gui_cache.memory_changed == nil or force then
      player_data.gui_cache.memory_changed = {}
    end

    local pmc = player_data.gui_cache.memory_changed[channel]
    local smc = state.gui_cache.memory_changed[channel]

    if not (pmc and smc) or (UpdateMinDelay <= smc - pmc) and (smc <= game.tick) then
      player_data.gui_cache.memory_changed[channel] = game.tick
      smc = 0
    end
    return smc - game.tick
  end

  local sync_delay = TestImpl(force)
  local notSync = 0 < sync_delay

  if player_data.gui_memory_sync_label then
    player_data.gui_memory_sync_label.caption = {"gui-fcpu-memviewer.memory-view-sync", (notSync and ' in '..sync_delay or '')}
  end
  if player_data.gui_memory_sync_sprite then
    player_data.gui_memory_sync_sprite.sprite =
    state.need_sync and 'flib_indicator_red'
    or notSync and 'flib_indicator_black'
    or 'flib_indicator_green'
  end
  return (sync_delay < 0) and not force
end

-------------------------------------------------------------------------------------------------------

local function ioChannel_GUI_Update_cl(channel)
  return function(player_data, state, force)
    if ioChannel_GUI_Validate(player_data, state, channel, force) then
      return true
    end
    -- Memory channels
    local ics = state.program_ics[channel]
    if ics and ics.out and ics.out.valid then
      local control = ics.out.get_control_behavior()
      --if control.signals_last_tick then
        local network = control.get_circuit_network(ics.out_connector or defines.wire_connector_id.combinator_output_red)
        local memmap = state.memmap[channel]
        if network then
          MemoryView.UpdateFromTable(player_data, network.signals, nil, nil, memmap)
        else
          MemoryView.UpdateFromTable(player_data, control.signals_last_tick, nil, nil, memmap)
        end
        return true
      --[[else
        if ics.value then
          local vc = ics.value.get_control_behavior()
          if vc.enabled and vc.parameters then
            MemoryView.UpdateFromTable(player_data, vc.parameters, 1)
            return true
          end
        end

        local network = control.get_circuit_network(defines.wire_connector_id.combinator_output_red)
        if network then
          MemoryView.UpdateFromTable(player_data, network.signals)
          return true
        end
      end]]
    end
  end
end

local function ioRegisters_GUI_Update(player_data, state, force)
  -- Registers
  MemoryView.UpdateFromTable(player_data, state.regs, 0, true)
  return true
end

local function ioWire_GUI_Update_cl(wire_connector)
  -- Input wires
  return function(player_data, state, force)
    local control = state.entity.get_control_behavior()
    local input = control.get_circuit_network(wire_connector)
    MemoryView.UpdateFromTable(player_data, input and input.signals)
    return true
  end
end

local function io_GUI_Update_cl(wire_connector)
  return function(player_data, state, force)
    -- Output
    --if ioChannel_GUI_Validate(player_data, state, 'output', force) then
    --  return true
    --end
    if state.program_ics.output then
      local control = state.program_ics.output.value.get_control_behavior()
      local network = control.get_circuit_network(defines.wire_connector_id.circuit_red)
      if network then
        MemoryView.UpdateFromTable(player_data, network.signals)
        return true
      end
    end
  end
end

local function ioWire_GUI_Update_output_cl(wire_connector)
  -- Scalar output buffer
  return function(player_data, state, force)
    if state.program_ics.output then
      local control = state.program_ics.output.value.get_control_behavior()
      MemoryView.UpdateFromTable(player_data, control and control.sections[1].filters, 1, true)
      return true
    end
  end
end

local function ioOutput_GUI_Update_cl(wire_connector)
  return function(player_data, state, force)
    -- Vector output
    --if ioChannel_GUI_Validate(player_data, state, 'output', force) then
    --  return true
    --end
    if state.ics_stack.output then
      local ics = state.program_ics[state.ics_stack.output]
      if ics then
        local control = (ics.out or ics.kout).get_control_behavior()
        MemoryView.UpdateFromTable(player_data, control and control.parameters and control.signals_last_tick)
        return true
      end
    end
  end
end

  -------------------------------------------------------------------------------------------------------

local ChannelsInfo = {
  { title = { 'gui-fcpu-memviewer.channel-registers' }, handler = ioRegisters_GUI_Update },
  { title = { 'gui-fcpu-memviewer.channel-input-red' }, handler = ioWire_GUI_Update_cl(defines.wire_connector_id.combinator_input_red) },
  { title = { 'gui-fcpu-memviewer.channel-input-green' }, handler = ioWire_GUI_Update_cl(defines.wire_connector_id.combinator_input_green) },
  { title = { 'gui-fcpu-memviewer.channel-input-lognet' }, handler = ioChannel_GUI_Update_cl('lognet') },
  { title = { 'gui-fcpu-memviewer.channel-output-scalar' }, handler = ioWire_GUI_Update_output_cl() },
  { title = { 'gui-fcpu-memviewer.channel-output-vector' }, handler = ioOutput_GUI_Update_cl() },
  { title = { 'gui-fcpu-memviewer.channel-output' }, handler = io_GUI_Update_cl() },
--  { title = { 'gui-fcpu-memviewer.channel-output-scalar-red' }, handler = ioWire_GUI_Update_output_cl(defines.wire_connector_id.combinator_output_red) },
--  { title = { 'gui-fcpu-memviewer.channel-output-scalar-green' }, handler = ioWire_GUI_Update_output_cl(defines.wire_connector_id.combinator_output_green) },
--  { title = { 'gui-fcpu-memviewer.channel-output-vector-red' }, handler = ioOutput_GUI_Update_cl(defines.wire_connector_id.combinator_output_red) },
--  { title = { 'gui-fcpu-memviewer.channel-output-vector-green' }, handler = ioOutput_GUI_Update_cl(defines.wire_connector_id.combinator_output_green) },
--  { title = { 'gui-fcpu-memviewer.channel-output-red' }, handler = io_GUI_Update_cl(defines.wire_connector_id.combinator_output_red) },
--  { title = { 'gui-fcpu-memviewer.channel-output-green' }, handler = io_GUI_Update_cl(defines.wire_connector_id.combinator_output_green) },
}
local MC_OUTPUT_CHANNEL_index = #ChannelsInfo
local MC_MEMORY_CHANNELS_from = MC_OUTPUT_CHANNEL_index
for i = 1, MC_MEMORY_CHANNELS do
  ChannelsInfo[MC_MEMORY_CHANNELS_from + i] = {
    title = { 'gui-fcpu-memviewer.channel-memory-bank', i },
    handler = ioChannel_GUI_Update_cl('mem'.. i)
  }
end

-------------------------------------------------------------------------------------------------------

function MemoryView.CreateWidget(rootGui)
  local memchannels = {}
  for k, info in ipairs(ChannelsInfo) do
    memchannels[k] = info.title
  end

  local elems = gui.build(rootGui, {
    {type="frame", name="fcpu-memory-view", save_as="gui_memory_view", style="entity_frame", style_mods={ minimal_width=364 }, direction="vertical", children={
      {template="heading_3", caption={"gui-fcpu-memviewer.memory-channel"}},
      {type="flow", name="fcpu-panels", direction="horizontal", style_mods={ vertical_align='center' }, children={
        {type='drop-down', save_as='gui_memory_channel', items={ table.unpack(memchannels) }, selected_index=1, handlers="memory.channel_switch"},
        {template="pushers.horizontal"},
        {type='checkbox', save_as='gui_memory_autoselect', state=false, caption={'gui-fcpu-memviewer.autoselect-channel'}, tooltip={"gui-fcpu-memviewer.autoselect-channel-tooltip"}, handlers="memory.channel_autoselect"},
      }},

      {type="frame", direction="vertical", style="invisible_frame", children={
        {type="flow", direction="horizontal", style_mods={ vertical_align='center' }, children={
          {template="heading_3", caption={"gui-fcpu-memviewer.memory-view"}},
          {template="pushers.horizontal"},
          {type="flow", style="flib_indicator_flow", children={
            {type="sprite", save_as='gui_memory_sync_sprite', style="flib_indicator", sprite="flib_indicator_black"},
            {type="label", save_as='gui_memory_sync_label', style_mods={ minimal_width=70, left_padding=4 }, caption={"gui-fcpu-memviewer.memory-view-sync"}, tooltip={"gui-fcpu-memviewer.memory-view-sync-tooltip"}},
          }},
        }},
        {type="scroll-pane", direction="vertical", children={
          {type="table", save_as="gui_memory_cells", style="slot_table", column_count=8 --[[ will be populated in `MemoryView.UpdateFromTable` ]]},
        }}
      }}
    }}
  });

  return elems
end

function MemoryView.DestroyWidget(player_data)
  if not player_data or not player_data.gui_fcpu or not player_data.gui_fcpu["fcpu-panels"] or not player_data.gui_fcpu["fcpu-panels"]["fcpu-memory-view"] then
    return
  end

  player_data.gui_fcpu["fcpu-panels"]["fcpu-memory-view"].destroy()
  player_data.gui_memory_view = nil
  player_data.gui_memory_cells = nil
end

function MemoryView.UpdateWidget(player_data, state, initial)
  if not player_data.gui_memory_channel then return end
  local index = player_data.gui_memory_channel.selected_index

  if player_data.gui_cache and player_data.gui_memory_autoselect and player_data.gui_memory_autoselect.state then
    if state.gui_cache.memory_autochannel then
      if state.gui_cache.memory_autochannel == 'output' then
        index = MC_OUTPUT_CHANNEL_index or index
      else
        local bank = tonumber(string.sub(state.gui_cache.memory_autochannel, 4))
        index = bank and (MC_MEMORY_CHANNELS_from + bank) or index
      end
      player_data.gui_memory_channel.selected_index = index
    end
  end

  if initial then
    if player_data.gui_memory_sync_label then
      player_data.gui_memory_sync_label.caption = {"gui-fcpu-memviewer.memory-view-sync", ''}
    end
  end

  if state then
    index = math.max(1, index)

    local info = ChannelsInfo[index]
    if info then
      if info.handler(player_data, state, initial) then
        return
      end
    end
  end

  MemoryView.UpdateFromTable(player_data, {})
end

local function PrepareRemap(signals, s2i)
  local first
  local last
  local remap = {}
  local queue = {}
  if s2i then
    for _,s in ipairs(signals) do
      local hash = hashSignalType(s.signal)
      local index = s2i[hash]
      if index then
        remap[index] = s
        --queue[#queue + 1] = signals[index]
        first = index < (first or 999999) and index or first
        last = (last or -99999) < index and index or last
      else
        queue[#queue + 1] = s
      end
    end
    local i = 1
    for _,s in ipairs(queue) do
      while remap[i] do
        i = i + 1
      end
      remap[i] = s
      i = i + 1
    end
    first = math.max(first or 1, i)
    last = math.max(last or 1, i)
  else
    remap = signals
    first = 1
    last = table_size(signals)
  end
  return remap, first, last
end

local function CleanCellRange(cells, first, last, style)
  local i = first
  while i <= last and cells[i] do
    local cell = cells[i]
    cell.tooltip = {'gui-fcpu-memviewer.memory-cell-tooltip-scalar', ''}
    cell.visible = true
    cell.sprite = nil
    cell.number = nil
    cell.style = style
    i = i + 1
  end
end

local function SetCell(player_data, cell, signal, idx, format, style)
  if signal and cell then
    if not signal.signal then
      signal = {
        count = signal.min,
        signal = signal.value
      }
    end

    local sprite = GUI_signalToSpritePath(player_data, signal.signal)

    cell.sprite = sprite
    cell.visible = true

    cell.style = idx and style.index or style.readonly
    cell.tooltip = idx and {'gui-fcpu-memviewer.memory-cell-tooltip-index', idx}
    or signal.signal and signal.signal.name and {'gui-fcpu-memviewer.memory-cell-tooltip-vector', GUI_signalToTooltip(signal)}
    or {'gui-fcpu-memviewer.memory-cell-tooltip-scalar', ''}

    if format == 0 then
      cell.number = signal.count
    else
      cell.number = sprite and signal.count or nil
    end

    if sprite or format then
      return true
    end
  end
end

function MemoryView.UpdateFromTable(player_data, signals, format, sparse, memmap)
  local cells = player_data.gui_memory_cells.children
  if not cells then
    return
  end

  if not signals then
    signals = {}
  end

  local style = {
    empty = memmap and "fcpu_channel_cell" or "fcpu_channel_empty_cell",
    readonly = memmap and "fcpu_channel_cell_ro" or "fcpu_channel_empty_cell",
    index = format == 0 and "fcpu_scalar_cell" or "fcpu_channel_cell_indexed",
  }

  -- order is different than in Factorio
  local remap, first, last = PrepareRemap(signals, memmap and memmap.s2i)
  local i2s = memmap and memmap.i2s or {}

  -- add extra
  for i = table_size(cells) + 1, math.max(MC_MEMORY_SLOTS_MIN, last) do
    gui.build(player_data.gui_memory_cells, {
      gui.templates.channel_cell('index-'..i, {visible=false})
    })
  end
  cells = player_data.gui_memory_cells.children

  -- clean beginning
  CleanCellRange(cells, 1, first - 1, style.empty);
  local idx = first

  -- show and setup visible
  for k,signal in pairs(remap) do
    if SetCell(player_data, cells[k], signal, i2s[k] and k or (format == 0) and k, format, style) then
      idx = k + 1
    elseif not sparse then
      break
    end
  end

  -- clean ending
  CleanCellRange(cells, idx, MC_MEMORY_SLOTS_MIN, style.empty)

  -- hide others
  while idx <= table_size(cells) and cells[idx] and cells[idx].visible do
    cells[idx].visible = false
    idx = idx + 1
  end
end

-------------------------------------------------------------------------------------------------------

function MemoryView.RegisterHandlers()
  gui.add_handlers{
    memory={
      channel_switch = {
        on_gui_selection_state_changed = GUI_mixPlayerData(function(player_data, state)
          if player_data.gui_memory_autoselect then
            player_data.gui_memory_autoselect.state = false
          end
          if player_data.gui_memory_view then
            MemoryView.UpdateWidget(player_data, state, true)
          end
        end)
      },

      channel_autoselect = {
        on_gui_checked_state_changed = GUI_mixPlayerData(function(player_data, state)
          if player_data.gui_memory_autoselect and not player_data.gui_memory_autoselect.state then
            return
          end
          if player_data.gui_memory_view then
            MemoryView.UpdateWidget(player_data, state, true)
          end
        end)
      },
    },
  }
end

-------------------------------------------------------------------------------------------------------

function MemoryView.setup(gui_)
  gui = gui_
  MemoryView.RegisterHandlers()
end
return MemoryView
