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
    update_debug_enabled()
  end
  if event.setting == "fcpu-maximum-updates-per-tick" then
    fcpu_maximum_updates_per_tick = settings.global[event.setting].value
  end
end


UpdateModSetting{setting = "fcpu-debug-enabled"}
UpdateModSetting{setting = "fcpu-maximum-updates-per-tick"}


--local hasProfiler, Profiler = pcall(require, '__profiler__/profiler')
--return hasProfiler and Profiler or nil
