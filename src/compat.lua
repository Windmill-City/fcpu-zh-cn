Compatibility = {}
-- Compatibility['mod_name'] = <expot_table>

if mods then
  -- Prototype phase
  for mod_name, _ in pairs(mods) do
    local ok, result = pcall(require, "compat/" .. mod_name .. "-proto")
    if ok then
      Compatibility[mod_name] = result
      log("Compatibility module loaded for mod '" .. mod_name .."'")
    end
  end
elseif script and script.active_mods then
  -- Runtime phase

  local handlers = {
    wiki_register = {},
    on_init = {},
    on_load = {},
    on_configuration_changed = {},
  }

  local function append_handlers(handlers, result)
    if type(result) == 'table' then
      for k,_ in pairs(handlers) do
        if type(result[k]) == 'function' then
          table.insert(handlers[k], result[k])
        end
      end
    end
  end

  for mod_name, _ in pairs(script.active_mods) do
    local ok, result = pcall(require, "compat/" .. mod_name .. "")
    if ok then
      Compatibility[mod_name] = result
      append_handlers(handlers, result)
      log("Compatibility module loaded for mod '" .. mod_name .."'")
    end
  end

  -- Compatibility[handler_name] = aggregate(handler_name, ( export_table['mod_name'], ... ))
  setmetatable(Compatibility, {
    __index = function(self, key)
      local handler = handlers[key]
      if handler then
        return function(...)
          for _,v in ipairs(handler) do
            v(...)
          end
        end
      end
    end
  })
end
