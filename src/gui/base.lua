-- require('mod-gui')

local gui = require("3rdparty.flib061.gui")
local MainView = require("src/gui/main")
local MemoryView = require("src/gui/memory")

-------------------------------------------------------------------------------------------------------

---@param signal SignalFilter
function GUI_signalToSpritePath(player_data, signal)
  if signal then
    local path
    if type(signal) == "string" then
      path = "item/".. signal
    elseif signal.type == "virtual" then
      path = "virtual-signal/" .. signal.name
    elseif signal.name then
      if signal.type then
        path = signal.type .. '/' .. signal.name
      else
        path = 'item/' .. signal.name
      end
    elseif signal.quality then
      path = 'quality/' .. signal.quality
    end
    if path and (player_data and player_data.gui_fcpu and player_data.gui_fcpu.gui) then
      if helpers.is_valid_sprite_path(path) then
        return path
      end
    end
  end
end

---@param signal OpRef_ValueOrString
function GUI_signalToTooltip(signal, prefix)
  local str = signal.count or ''
  if signal.str then
    str = '\''.. signal.str ..'\''
  elseif signal.signal then
    str = str .. signalToStr(signal.signal)
  end
  if prefix then
    return prefix .. (str and ('='.. str) or '')
  else
    return (str or '')
  end
end

--[[function GUI_lognetTooltip(index, item, count)
  if item and count then
    return '['.. index ..'] = '.. count ..'[item='.. item ..']'
  else
    return '['.. index ..'] = <'.. item ..'>'
  end
end]]

function GUI_mixPlayerData(proc)
  return function(event)
    local player_data, player = get_player_data(event.player_index)
    local state = get_fcpu_state(player_data.current_fcpu)
    if state then
      proc(player_data, state, event, player)
    end
  end
end

function GUI_reset_error_message(player_data)
  if player_data.gui_error_message and player_data.gui_error_message.valid then
    player_data.gui_error_message.caption = ""
  end
end

-------------------------------------------------------------------------------------------------------

local ControlHandlers = {}

ControlHandlers['fcpu-debug-reset'] = GUI_mixPlayerData(function(player_data, state)
  GUI_reset_error_message(player_data)
  Controller.set_error_message(state, nil)
  Controller.compile(state)
  Controller.halt(state, true)
end)

ControlHandlers['fcpu-debug-stop'] = GUI_mixPlayerData(function(player_data, state)
  Controller.compile(state)
  Controller.set_program_counter(state, 1)
  Controller.halt(state)
end)

ControlHandlers['fcpu-debug-start'] = GUI_mixPlayerData(function(player_data, state)
  GUI_reset_error_message(player_data)
  Controller.compile(state)
  Controller.run(state)
end)

ControlHandlers['fcpu-debug-restart'] = GUI_mixPlayerData(function(player_data, state)
  Controller.halt(state)
  Controller.set_program_counter(state, 1)
  Controller.run(state)
end)

ControlHandlers['fcpu-debug-pause'] = GUI_mixPlayerData(function(player_data, state)
  if Controller.is_running(state) then
    Controller.compile(state)
    Controller.halt(state)
  end
end)

ControlHandlers['fcpu-debug-step-over'] = GUI_mixPlayerData(function(player_data, state)
  GUI_reset_error_message(player_data)
  Controller.compile(state)
  Controller.step(state)
end)

ControlHandlers['fcpu-debug-step-into'] = GUI_mixPlayerData(function(player_data, state)
  if not Controller.is_sleeping(state) then
    GUI_reset_error_message(player_data)
    Controller.compile(state)
    Controller.step(state)
  end
end)

-------------------------------------------------------------------------------------------------------

MainView.setup(gui, MemoryView, ControlHandlers)
MemoryView.setup(gui)
gui.register_handlers()

-------------------------------------------------------------------------------------------------------

-- Close default gui when it will be opened.
script.on_event(defines.events.on_gui_opened, function(event)
  if gui.dispatch_handlers(event) then return end

  local entity = event.entity
  if entity and entity.valid and entity.name == "fcpu" then
    local player_data, player = get_player_data(event.player_index)
    if player_data and player_data.gui_fcpu and player_data.gui_fcpu.valid then
      if player_data.gui_pinned then
        player.opened = nil
      else
        player.opened = player_data.gui_fcpu
      end
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
    GuiWidgetClose(event.player_index, true)
  end
end)

-- Handle fCPU GUI Close event.
script.on_event("fcpu-close", function(event)
  GuiWidgetClose(event.player_index, true)
end)
script.on_event("fcpu-escape", function(event)
  GuiWidgetClose(event.player_index, true)
end)

-- Handle debug hotkeys
script.on_event("fcpu-debug-stop", ControlHandlers['fcpu-debug-stop'])
script.on_event("fcpu-debug-start", ControlHandlers['fcpu-debug-start'])
script.on_event("fcpu-debug-restart", ControlHandlers['fcpu-debug-restart'])
script.on_event("fcpu-debug-pause", ControlHandlers['fcpu-debug-pause'])
script.on_event("fcpu-debug-step-over", ControlHandlers['fcpu-debug-step-over'])
script.on_event("fcpu-debug-step-into", ControlHandlers['fcpu-debug-step-into'])

-- Handle player move event to close GUI when out of range.
script.on_event(defines.events.on_player_changed_position, function(event)
  local player_data, player = get_player_data(event.player_index)
  if player_data and player_data.current_fcpu and player_data.gui_fcpu then
    if not player.can_reach_entity(player_data.current_fcpu) then
      GuiWidgetClose(event.player_index, false, true)
    end
  end
end)

return gui