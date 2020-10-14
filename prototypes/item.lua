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


local fcpu = table.shallow_merge(table.deep_copy(data.raw['arithmetic-combinator']['arithmetic-combinator']), generate_fcpu_combinator{
  name = "fcpu",
  icon = "__fcpu__/graphics/icons/fcpu.png",
  minable = {hardness = 0.2, mining_time = 0.5, result = "fcpu"},
  max_health = 300,
  collision_box = {{-0.65, -0.65}, {0.65, 0.65}},
  selection_box = {{-1, -1}, {1, 1}},
  additional_pastable_entities = {"fcpu", "arithmetic-combinator", "decider-combinator", "constant-combinator"},

  active_energy_usage = "20KW",

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
    ingredients = {{"arithmetic-combinator", 10}, {"decider-combinator", 10}, {"processing-unit", 1}},
    energy_required = 20,
    results = {{"fcpu", 1}},
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
    prerequisites = {"circuit-network", "advanced-electronics-2"},
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

require('legacy/imposter_fcpu')

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
    "player-creation",
    "placeable-off-grid",
    "not-repairable",
    "not-on-map",
    "not-blueprintable",
    "not-deconstructable", -- can't be deconstructed by 'demolition blueprint'. reducing bounds marker spam
    "hidden",
    "hide-alt-info",
    "not-flammable",
    "not-in-kill-statistics",
  },
  collision_mask = {"not-colliding-with-itself"},

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

  collision_mask = {"not-colliding-with-itself"},
})
if not MC_DEBUG then hdl_constant_fcpu = table.shallow_merge(hdl_constant_fcpu, {
  selectable_in_game = false,
  draw_circuit_wires = false,

  flags = {
    "not-rotatable",
    "player-creation",
    "placeable-off-grid",
    "not-repairable",
    "not-on-map",
    "not-blueprintable",
    "not-deconstructable", -- can't be deconstructed by 'demolition blueprint'. reducing bounds marker spam
    "hidden",
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

  collision_mask = {"not-colliding-with-itself"},
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
    "hidden",
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

  collision_mask = {"not-colliding-with-itself"},
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
    "hidden",
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
  hdl_output_fcpu,
  hdl_constant_fcpu,
  hdl_decider_fcpu,
  hdl_arithmetic_fcpu,
}