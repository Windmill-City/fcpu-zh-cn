local function util_get_blueprint(item_stack) -- @raiguard
  if not item_stack or not item_stack.valid_for_read then
    return
  end
  local blueprint
  if item_stack.is_blueprint then
    blueprint = item_stack
  elseif item_stack.is_blueprint_book and item_stack.active_index then
    local inventory = item_stack.get_inventory(defines.inventory.item_main) --[[@as LuaInventory]]
    if inventory.is_empty() or item_stack.active_index > #inventory then
      return
    end
    blueprint = util_get_blueprint(inventory[item_stack.active_index])
  end

  if blueprint and blueprint.is_blueprint_setup() then
    return blueprint
  end
end

local function swap_words(str, a, b, bound)
  if not bound then
    bound = "%l"
  end

  local function escape(s)
      return (s:gsub("([^"..bound.."])", "%%%1"))
  end

  local A = escape(a)
  local B = escape(b)
  local TMP = "__SWAP_TMP__"

  -- заменяем только целые слова (%f[%w] — frontier pattern)
  str = str:gsub("%f["..bound.."]"..A.."%f[^"..bound.."]", TMP)
  str = str:gsub("%f["..bound.."]"..B.."%f[^"..bound.."]", a)
  str = str:gsub(TMP, b)

  return str
end

local function on_swap_wire_colors(player)
  local blueprint = util_get_blueprint(player.cursor_stack)
  if not blueprint then
    return
  end

  local entities = blueprint.get_blueprint_entities()
  if not entities then
    return
  end

  for _, entity in pairs(entities) do
    if is_fcpu(entity) then
      local text = entity.tags.fcpu.t
      text = swap_words(text, "red", "green")
      entity.tags.fcpu.t = text
    end
  end

  blueprint.set_blueprint_entities(entities)
end

local hkEventName = "bpt-swap-wire-colors"
hkPrevHandler = script.get_event_handler(hkEventName)
script.on_event(hkEventName, function(event)
  on_swap_wire_colors(game.get_player(event.player_index))
  if hkPrevHandler then
    hkPrevHandler(event)
  end
end)

local btnEventName = "on_gui_click"
btnPrevHandler = script.get_event_handler(btnEventName)
script.on_event(btnEventName, function(event)
  -- omg...
  if event.element
  and event.element.tags
  and event.element.tags.BlueprintTools
  and event.element.tags.BlueprintTools.flib
  and event.element.tags.BlueprintTools.flib.on_click
  and event.element.tags.BlueprintTools.flib.on_click.action == 'swap_wire_colors' then
    on_swap_wire_colors(game.get_player(event.player_index))
  end
  if btnPrevHandler then
    btnPrevHandler(event)
  end
end)
