local function trim(s)
  return s:match("^%s*(.-)%s*$")
end

local function parse_args(root, arg_string)
  local args = {}
  for raw in string.gmatch(arg_string, "[^,]+") do
    raw = trim(raw)
    local str = raw:match("^'(.*)'$")
    if str then
      table.insert(args, str) -- 'string'
    elseif tonumber(raw) then
      table.insert(args, tonumber(raw)) -- number
    elseif raw:match("^defines%.") then
      -- defines.xxx.yyy
      local v = root
      for p in string.gmatch(raw, "[^%.]+") do
        v = v and v[p]
      end
      table.insert(args, v)
    else
      table.insert(args, nil)
    end
  end
  return args
end

local function split_segments(query)
  local segments = {}
  local buf = {}
  local paren = 0
  local bracket = 0
  for i = 1, #query do
    local ch = query:sub(i, i)
    if ch == "(" then
      paren = paren + 1
    elseif ch == ")" then
      paren = paren - 1
    elseif ch == "[" then
      bracket = bracket + 1
    elseif ch == "]" then
      bracket = bracket - 1
    end
    if ch == "." and paren == 0 and bracket == 0 then
      table.insert(segments, table.concat(buf))
      buf = {}
    else
      table.insert(buf, ch)
    end
  end
  if #buf > 0 then
      table.insert(segments, table.concat(buf))
  end
  return segments
end

local function parse_segment(seg)
  -- function call
  local fname, argstr = seg:match("^([%w_]+)%((.*)%)$")
  if fname then
    return {
      kind = "call",
      name = fname,
      args = argstr
    }
  end

  -- field[index]
  local field, index = seg:match("^([%w_]+)%[(.+)%]$")
  if field then
    return {
      kind = "index",
      name = field,
      index = index
    }
  end

  -- plain field
  return {
    kind = "field",
    name = seg
  }
end

local QUALITY_FIRST_METHODS = {
  -- LuaEntityPrototype
  get_inventory_size = true,
  get_crafting_speed = true,
  get_supply_area_distance = true,
  get_max_wire_distance = true,
  get_max_circuit_wire_distance = true,
  get_max_energy_usage = true,
  get_max_energy_production = true,
  get_max_energy = true,
  get_inserter_extension_speed = true,
  get_inserter_rotation_speed = true,
  get_researching_speed = true,
  get_max_distance_of_sector_revealed = true,
  get_max_distance_of_nearby_sector_revealed = true,
  get_max_health = true,
  get_fluid_usage_per_tick = true,
  get_max_power_output = true,
  get_pumping_speed = true,
  get_valve_flow_rate = true,
  get_mining_drill_radius = true,
  get_fluid_capacity = true,
  get_attraction_range_elongation = true,
  get_energy_distribution_efficiency = true,
  -- LuaItemPrototype
  get_spoil_ticks = true,
  get_inventory_size_bonus = true,
}

local function eval_chain(root, query, quality, depth)
  depth = (depth or 0) + 1
  if depth > 16 then return nil end

  local current = root
  local segments = split_segments(query)

  for _, seg in ipairs(segments) do
    if current == nil then return nil end

    local node = parse_segment(seg)

    if node.kind == "field" then
      current = current[node.name]

    elseif node.kind == "index" then
      current = current[node.name]
      if current == nil then return nil end

      local idx = eval_chain(_G, node.index, quality, depth)
      if idx == nil then return nil end

      current = current[idx]

    elseif node.kind == "call" then
      local fn = current[node.name]
      if type(fn) ~= "function" then return nil end

      local args = {}
      if node.args ~= "" then
        args = parse_args(_G, node.args)
      end
      if quality ~= nil and QUALITY_FIRST_METHODS[node.name] then
        table.insert(args, quality)
      end

      local ok, result = pcall(fn, table.unpack(args))
      if not ok then return nil end

      current = result
    end
  end

  return current
end

local function ugpf(type_name, name, quality, query)
  local protolist = prototypes[type_name]
  if not protolist then
    Assert.exception(Errors.UnknownPrototypeGroup(type_name))
  end

  local proto = protolist[name]
  if not proto then
    Assert.exception(Errors.UnknownPrototype(name))
  end
  
  local success, value = pcall(eval_chain, proto, query, quality)
  if not success then
    success, value = pcall(eval_chain, proto.place_result, query, quality)
  end
  Assert.check(success, value)

  return value
end

return ugpf