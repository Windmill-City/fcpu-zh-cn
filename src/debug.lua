local function debug_print_real(...)
  local s = ""
  for _,v in ipairs({...}) do
    s = s .. tostring(v)
  end
  if (fcpu_debug_enabled % 2) == 1 then
    game.print(s)
  end
  if (fcpu_debug_enabled / 2 % 2) == 1 then
    log(s)
  end
end

local function update_debug_enabled()
  if fcpu_debug_enabled and 0 < fcpu_debug_enabled then
    debug_print = debug_print_real
  else
    debug_print = function()end
  end
end

function UpdateModSetting(event)
  if event.setting == "fcpu-debug-enabled" then
    local log_format_map = {d=0, c=1, l=2, b=3}
    fcpu_debug_enabled = log_format_map[settings.global[event.setting].value]
    if MC_DEBUG and fcpu_debug_enabled == 0 then
      fcpu_debug_enabled = 1
    end
    update_debug_enabled()
  end
  if event.setting == "fcpu-gui-updates-every-tick" then
    fcpu_gui_updates_every_tick = settings.global[event.setting].value
  end
  if event.setting == "fcpu-maximum-updates-per-tick" then
    fcpu_maximum_updates_per_tick = settings.global[event.setting].value
  end
end

function debug_assert(value)
  if fcpu_debug_enabled and 0 < fcpu_debug_enabled then
    assert(value)
  end
end

function debug_notify(state, msg)
  if fcpu_debug_enabled and 0 < fcpu_debug_enabled then
    if state then
      if state.entity then
        rendering.draw_text{
          text = state.entity.unit_number ..' > #'.. state.index ..' '.. (msg or ''),
          surface = state.entity.surface,
          target  = state.entity,
          color = {r=1,g=1},
          time_to_live = 60,
          alignment = 'center',
        }
      else
        game.print('#'.. state.index ..' '.. msg)
      end
    else
      game.print(msg)
    end
  end
end


UpdateModSetting{setting = "fcpu-debug-enabled"}
UpdateModSetting{setting = "fcpu-gui-updates-every-tick"}
UpdateModSetting{setting = "fcpu-maximum-updates-per-tick"}
