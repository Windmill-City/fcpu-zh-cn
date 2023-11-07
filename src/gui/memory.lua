local gui = require("3rdparty.flib061.gui")
local MemoryView = {}

-------------------------------------------------------------------------------------------------------

function MemoryView.CreateWidget(rootGui)
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
      {type="flow", name="fcpu-panels", direction="horizontal", style_mods={ vertical_align='center' }, children={
        {type='drop-down', save_as='gui_memory_channel', items={ table.unpack(memchannels) }, selected_index=1, handlers="memory.memory_channel"},
        {template="pushers.horizontal"},
        {type='checkbox', save_as='gui_memory_autoselect', state=false, caption={'gui-fcpu-memviewer.autoselect-channel'}},
      }},

      {type="flow", direction="horizontal", style_mods={ vertical_align='center' }, children={
        {template="heading_3", caption={"gui-fcpu-memviewer.memory-view"}},
        {template="pushers.horizontal"},
        {type="flow", style="flib_indicator_flow", children={
          {type="sprite", save_as='gui_memory_sync_sprite', style="flib_indicator", sprite="flib_indicator_blue"},
          {type="label", save_as='gui_memory_sync_label', style_mods={ minimal_width=70 }, caption={"gui-fcpu-memviewer.memory-view-sync"}},
        }},
      }},
      {type="scroll-pane", style="scroll_pane_in_shallow_frame", direction="vertical", children={
        {type="table", save_as="gui_memory_cells", style="slot_table", column_count=8 --[[ will be populated in `MemoryView.UpdateFromTable` ]]},
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

function MemoryView.UpdateFromTable(player_data, signals, sort, sparse, order)
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
          local sprite = GUI_signalToSpritePath(player_data, v.signal)
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

local UpdateMinDelay = 0
function MemoryView.UpdateWidget(player_data, state, initial)
  if not player_data.gui_memory_channel then return end
  local index = player_data.gui_memory_channel.selected_index

  if player_data.gui_cache and player_data.gui_memory_autoselect and player_data.gui_memory_autoselect.state then
    if state.gui_cache.memory_autochannel then
      index = tonumber(string.sub(state.gui_cache.memory_autochannel, 4)) or index
      player_data.gui_memory_channel.selected_index = index
    end
  end

  if state then
    index = math.max(1, index)

    local ValidateGuiCacheImpl = function(channel)
      player_data.gui_cache = player_data.gui_cache or {}
      if player_data.gui_cache.memory_changed == nil or initial then
        player_data.gui_cache.memory_changed = {}
      end
      if state.gui_cache.memory_changed == nil then
        return false
      end

      local pmc = player_data.gui_cache.memory_changed[channel]
      local smc = state.gui_cache.memory_changed[channel]

      if not (pmc and smc) or (pmc + UpdateMinDelay <= smc) and (smc <= game.tick) then
        player_data.gui_cache.memory_changed[channel] = smc
        return false
      end
      return true
    end

    local ValidateGuiCache = function(channel)
      local result = ValidateGuiCacheImpl(channel)

      local sync_delay
      if state.gui_cache.memory_changed then
        sync_delay = state.gui_cache.memory_changed[channel] - game.tick
      end
      if player_data.gui_memory_sync_label then
        player_data.gui_memory_sync_label.caption = {"gui-fcpu-memviewer.memory-view-sync", (0 < sync_delay and ' in '..sync_delay or '')}
      end
      if player_data.gui_memory_sync_sprite then
        player_data.gui_memory_sync_sprite.sprite =
        state.need_sync and 'flib_indicator_red'
        or 0 < sync_delay and 'flib_indicator_black'
        or 'flib_indicator_green'
      end
      return result
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
            MemoryView.UpdateFromTable(player_data, network.signals)
            --MemoryView.UpdateFromTable(player_data, network.signals, 0, true, control.signals_last_tick)
          else
            MemoryView.UpdateFromTable(player_data, control.signals_last_tick)
          end
          return
        else
          if ics.value then
            local vc = ics.value.get_control_behavior()
            if vc.enabled and vc.parameters then
              MemoryView.UpdateFromTable(player_data, vc.parameters, 1)
              return
            end
          end

          local network = control.get_circuit_network(defines.wire_type.red, defines.circuit_connector_id.combinator_output)
          if network then
            MemoryView.UpdateFromTable(player_data, network.signals)
            return
          end
        end
      end
    elseif index == MC_MEMORY_CHANNELS + 1 then
      -- Registers
      MemoryView.UpdateFromTable(player_data, state.regs, 0, true)
      return
    elseif index == MC_MEMORY_CHANNELS + 2 then
      -- Input wires (RED)
      local control = state.entity.get_control_behavior()
      local input = control.get_circuit_network(defines.wire_type.red, defines.circuit_connector_id.combinator_input)
      MemoryView.UpdateFromTable(player_data, input and input.signals)
      return
    elseif index == MC_MEMORY_CHANNELS + 3 then
      -- Input wires (GREEN)
      local control = state.entity.get_control_behavior()
      local input = control.get_circuit_network(defines.wire_type.green, defines.circuit_connector_id.combinator_input)
      MemoryView.UpdateFromTable(player_data, input and input.signals)
      return
    elseif index == MC_MEMORY_CHANNELS + 4 then
      if ValidateGuiCache('output') then return end
      -- Output buffer
      if state.program_ics.output then
        local control = state.program_ics.output.value.get_control_behavior()
        MemoryView.UpdateFromTable(player_data, control and control.parameters, 1, true)
        return
      end
    elseif index == MC_MEMORY_CHANNELS + 5 then
      -- Vector output
      if state.ics_stack.output and state.program_ics[state.ics_stack.output] then
        local control = state.program_ics[state.ics_stack.output].out.get_control_behavior()
        MemoryView.UpdateFromTable(player_data, control and control.parameters and control.signals_last_tick)
        return
      end
    elseif index == MC_MEMORY_CHANNELS + 6 then
      -- Output
      if state.program_ics.output then
        local control = state.program_ics.output.value.get_control_behavior()
        local network = control.get_circuit_network(defines.wire_type.red, defines.circuit_connector_id.constant_combinator)
        if network then
          MemoryView.UpdateFromTable(player_data, network.signals)
          return
        end
      end
    end
  end

  MemoryView.UpdateFromTable(player_data, {})
end

-------------------------------------------------------------------------------------------------------

function MemoryView.RegisterHandlers()
  gui.add_handlers{
    memory={
      memory_channel = {
        on_gui_selection_state_changed = GUI_mixPlayerData(function(player_data, state)
          if player_data.gui_memory_autoselect then
            player_data.gui_memory_autoselect.state = false
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
