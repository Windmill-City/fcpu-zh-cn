require('prototypes/entities/pictures')

function table.shallow_merge(tblA, tblB, array_merge, raw)
  if not tblB then
      return tblA
  end
  if array_merge then
      for _, v in pairs(tblB) do
          Table.insert(tblA, v)
      end
  else
      for k, v in pairs(tblB) do
          if raw then
              rawset(tblA, k, v)
          else
              tblA[k] = v
          end
      end
  end
  return tblA
end

local empty_picture = {
  filename = "__core__/graphics/empty.png",
  x = 0,
  y = 0,
  width = 1,
  height = 1,
  frame_count = 1,
  shift = {0, 0},
}
local empty_animation = empty_picture


local fcpu = table.shallow_merge(table.deep_copy(data.raw['arithmetic-combinator']['arithmetic-combinator']), generate_fcpu_combinator{
  name = "fcpu",
  icon = "__fcpu__/graphics/icons/fcpu.png",
  minable = {hardness = 0.2, mining_time = 0.5, result = "fcpu"},
  max_health = 300,
  collision_box = {{-0.65, -0.65}, {0.65, 0.65}},
  selection_box = {{-1, -1}, {1, 1}},
  additional_pastable_entities = {"fcpu", "arithmetic-combinator", "decider-combinator", "constant-combinator"},

  active_energy_usage = "20kW",

  and_symbol_sprites = empty_picture,
  divide_symbol_sprites = empty_picture,
  left_shift_symbol_sprites = empty_picture,
  minus_symbol_sprites = empty_picture,
  modulo_symbol_sprites = empty_picture,
  multiply_symbol_sprites = empty_picture,
  or_symbol_sprites = empty_picture,
  plus_symbol_sprites = empty_picture,
  power_symbol_sprites = empty_picture,
  right_shift_symbol_sprites = empty_picture,
  xor_symbol_sprites = empty_picture,
})
if MC_DEBUG then fcpu = table.shallow_merge(fcpu, {
  circuit_wire_max_distance = 10000,
})
end

data:extend{
  fcpu,
  {
    type = "item",
    name = "fcpu",
    place_result = 'fcpu',
    icon = "__fcpu__/graphics/icons/fcpu.png",
    icon_size = 64,
    stack_size = 20,
    subgroup = "circuit-network",
    order = "c[combinators]-f[fcpu]"
  },
  {
    type = "recipe",
    name = "fcpu",
    enabled = false,
    ingredients = {
      {type = "item", name = "arithmetic-combinator", amount = 10},
      {type = "item", name = "decider-combinator", amount = 10},
      {type = "item", name = "processing-unit", amount = 1}
    },
    energy_required = 20,
    results = {
      {type = "item", name = "fcpu", amount = 1}
    },
    unlock_results = true
  },
  {
    type = "technology",
    name = "fcpu",
    icon_size = 128,
    icon = "__fcpu__/graphics/technology/fcpu.png",
    effects =
    {
      {
        type = "unlock-recipe",
        recipe = "fcpu"
      }
    },
    prerequisites = {"circuit-network", "processing-unit"},
    unit =
    {
      count = 200,
      ingredients =
      {
        {"automation-science-pack", 2},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1}
      },
      time = 45
    },
    order = "a-d-d"
  },
}

local hdl_lognet_fcpu = table.shallow_merge(table.deep_copy(data.raw['roboport']['roboport']), {
  name = "lognet-fcpu",
  energy_source = {
    type = "void",
    usage_priority = "primary-input"
  },
  energy_usage = "2kW",
  robot_slots_count = 0,
  material_slots_count = 0,

  logistics_radius = 0,
  construction_radius = 0,
  charging_energy = "0W",

  --default_available_logistic_output_signaloptional = { type = "virtual", name = "R" },
  --default_total_logistic_output_signaloptional = { type = "virtual", name = "R" },
  --default_available_construction_output_signaloptional = { type = "virtual", name = "R" },
  --default_total_construction_output_signal = { type = "virtual", name = "R" },
  circuit_wire_max_distance = 10000,

  draw_logistic_radius_visualization = false,
  draw_construction_radius_visualization = false,

  charging_station_count = 0,
  charging_offsets = {},
  robot_limit = 0,
})
if not MC_DEBUG then hdl_lognet_fcpu = table.shallow_merge(hdl_lognet_fcpu, {
  icon = "__fcpu__/graphics/icons/fcpu.png",
  icon_size = 1,
  icon_mipmaps = 0,
  allow_copy_paste = false,
  selectable_in_game = false,
  create_ghost_on_death = false,

  flags = {
    "not-rotatable",
    "placeable-off-grid",
    "not-repairable",
    "not-on-map",
    "not-blueprintable",
    "not-deconstructable", -- can't be deconstructed by 'demolition blueprint'. reducing bounds marker spam
    "not-in-made-in",
    "hide-alt-info",
    "not-flammable",
    "not-in-kill-statistics",
  },
  collision_mask = {
    layers = {},
    not_colliding_with_itself = true,
  },

  base = empty_picture,
  base_patch = empty_picture,
  base_animation = empty_animation,
  door_animation_up = empty_animation,
  door_animation_down = empty_animation,
  recharging_animation = empty_animation,
  circuit_connector_sprites = {
    led_red = empty_picture,
    led_green = empty_picture,
    led_blue = empty_picture,
    led_light = {
      intensity = 0,
      size = 0,
    },
  },

  draw_copper_wires = false,
  draw_circuit_wires = false,
})
end

local hdl_output_fcpu = table.shallow_merge(table.deep_copy(data.raw['constant-combinator']['constant-combinator']), {
  name = "output-fcpu",
  circuit_wire_max_distance = 10000,
  item_slot_count = MC_OUTPUT,
})
if not MC_DEBUG then hdl_output_fcpu = table.shallow_merge(hdl_output_fcpu, {
  icon = "__fcpu__/graphics/icons/fcpu.png",
  icon_size = 1,
  icon_mipmaps = 0,
  allow_copy_paste = false,
  selectable_in_game = false,
  draw_circuit_wires = false,
  create_ghost_on_death = false,

  flags = {
    "not-rotatable",
    "placeable-off-grid",
    "not-repairable",
    "not-on-map",
    "not-blueprintable",
    "not-deconstructable", -- can't be deconstructed by 'demolition blueprint'. reducing bounds marker spam
    "not-in-made-in",
    "hide-alt-info",
    "not-flammable",
    "not-in-kill-statistics",
  },
  collision_mask = {
    layers = {},
    not_colliding_with_itself = true,
  },

  sprites =
  {
      north = empty_picture,
      east = empty_picture,
      south = empty_picture,
      west = empty_picture,
  },
  activity_led_sprites =
  {
      north = empty_picture,
      east = empty_picture,
      south = empty_picture,
      west = empty_picture,
  },
})
end

local hdl_constant_fcpu = table.shallow_merge(table.deep_copy(data.raw['constant-combinator']['constant-combinator']), {
  name = "constant-fcpu",
  icon = "__fcpu__/graphics/icons/fcpu.png",
  icon_size = 1,
  icon_mipmaps = 0,
  allow_copy_paste = false,
  create_ghost_on_death = false,
  item_slot_count = 1,

  circuit_wire_max_distance = 10000,
  energy_source = {
    type = "void",
    usage_priority = "primary-input"
  },

  collision_mask = {
    layers = {},
    not_colliding_with_itself = true,
  },
})
if not MC_DEBUG then hdl_constant_fcpu = table.shallow_merge(hdl_constant_fcpu, {
  selectable_in_game = false,
  draw_circuit_wires = false,

  flags = {
    "not-rotatable",
    "placeable-off-grid",
    "not-repairable",
    "not-on-map",
    "not-blueprintable",
    "not-deconstructable", -- can't be deconstructed by 'demolition blueprint'. reducing bounds marker spam
    "not-in-made-in",
    "hide-alt-info",
    "not-flammable",
    "not-in-kill-statistics",
  },

  sprites =
  {
      north = empty_picture,
      east = empty_picture,
      south = empty_picture,
      west = empty_picture,
  },
  activity_led_sprites =
  {
      north = empty_picture,
      east = empty_picture,
      south = empty_picture,
      west = empty_picture,
  },
})
end

local hdl_decider_fcpu = table.shallow_merge(table.deep_copy(data.raw['decider-combinator']['decider-combinator']), {
  name = "decider-fcpu",
  icon = "__fcpu__/graphics/icons/fcpu.png",
  icon_size = 1,
  icon_mipmaps = 0,
  allow_copy_paste = false,
  create_ghost_on_death = false,

  circuit_wire_max_distance = 10000,
  energy_source = {
    type = "void",
    usage_priority = "primary-input"
  },

  collision_mask = {
    layers = {},
    not_colliding_with_itself = true,
  },
})
if not MC_DEBUG then hdl_decider_fcpu = table.shallow_merge(hdl_decider_fcpu, {
  selectable_in_game = false,
  draw_circuit_wires = false,

  flags = {
    "not-rotatable",
    "placeable-off-grid",
    "not-repairable",
    "not-on-map",
    "not-blueprintable",
    "not-deconstructable", -- can't be deconstructed by 'demolition blueprint'. reducing bounds marker spam
    "not-in-made-in",
    "hide-alt-info",
    "not-flammable",
    "not-in-kill-statistics",
  },

  equal_symbol_sprites = empty_picture,
  greater_or_equal_symbol_sprites = empty_picture,
  greater_symbol_sprites = empty_picture,
  less_or_equal_symbol_sprites = empty_picture,
  less_symbol_sprites = empty_picture,
  not_equal_symbol_sprites = empty_picture,

  sprites =
  {
      north = empty_picture,
      east = empty_picture,
      south = empty_picture,
      west = empty_picture,
  },
  activity_led_sprites =
  {
      north = empty_picture,
      east = empty_picture,
      south = empty_picture,
      west = empty_picture,
  },
})
end

local hdl_arithmetic_fcpu = table.shallow_merge(table.deep_copy(data.raw['arithmetic-combinator']['arithmetic-combinator']), {
  name = "arithmetic-fcpu",
  icon = "__fcpu__/graphics/icons/fcpu.png",
  icon_size = 1,
  icon_mipmaps = 0,
  allow_copy_paste = false,
  create_ghost_on_death = false,

  circuit_wire_max_distance = 10000,
  energy_source = {
    type = "void",
    usage_priority = "primary-input"
  },

  collision_mask = {
    layers = {},
    not_colliding_with_itself = true,
  },
})
if not MC_DEBUG then hdl_arithmetic_fcpu = table.shallow_merge(hdl_arithmetic_fcpu, {
  selectable_in_game = false,
  draw_circuit_wires = false,

  flags = {
    "not-rotatable",
    "placeable-off-grid",
    "not-repairable",
    "not-on-map",
    "not-blueprintable",
    "not-deconstructable", -- can't be deconstructed by 'demolition blueprint'. reducing bounds marker spam
    "not-in-made-in",
    "hide-alt-info",
    "not-flammable",
    "not-in-kill-statistics",
  },

  and_symbol_sprites = empty_picture,
  divide_symbol_sprites = empty_picture,
  left_shift_symbol_sprites = empty_picture,
  minus_symbol_sprites = empty_picture,
  modulo_symbol_sprites = empty_picture,
  multiply_symbol_sprites = empty_picture,
  or_symbol_sprites = empty_picture,
  plus_symbol_sprites = empty_picture,
  power_symbol_sprites = empty_picture,
  right_shift_symbol_sprites = empty_picture,
  xor_symbol_sprites = empty_picture,

  sprites =
  {
      north = empty_picture,
      east = empty_picture,
      south = empty_picture,
      west = empty_picture,
  },
  activity_led_sprites =
  {
      north = empty_picture,
      east = empty_picture,
      south = empty_picture,
      west = empty_picture,
  },
})
end

data:extend{
  hdl_lognet_fcpu,
  hdl_output_fcpu,
  hdl_constant_fcpu,
  hdl_decider_fcpu,
  hdl_arithmetic_fcpu,
}