require('prototypes/entities/pictures')
require('src/constants')

local empty_picture = {
  filename = "__fcpu__/graphics/empty.png",
  x = 0,
  y = 0,
  width = 1,
  height = 1,
  frame_count = 1,
  shift = {0, 0},
}


data:extend{
  table.merge(table.deepcopy(data.raw['arithmetic-combinator']['arithmetic-combinator']), generate_fcpu_combinator
  {
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
  }),
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


local imposter_fcpu_item ={
  type = "item",
  name = "imposter-fcpu",
  icon = "__fcpu__/graphics/icons/fcpu.png",
  icon_size = 1,
  flags = { "hidden" },
  subgroup = "circuit-network",
  place_result="imposter-fcpu",
  order = "c[combinators]-f[imposter-fcpu]",
  stack_size = 1,
}

local imposter_fcpu = table.merge(table.deepcopy(data.raw['constant-combinator']['constant-combinator']), {
  name = "imposter-fcpu",
  icon = "__fcpu__/graphics/icons/fcpu.png",
  icon_size = 1,
  icon_mipmaps = 0,
  allow_copy_paste = false,
  selectable_in_game = false,

  flags = {
    "not-rotatable",
    "player-creation",
    "placeable-off-grid",
    "not-repairable",
    "not-on-map",
    --"not-deconstructable", -- can't be deconstructed by 'demolition blueprint'. reducing bounds marker spam
    "hide-alt-info",
    "not-flammable",
    --"no-copy-paste",
    --"not-selectable-in-game",
    "not-in-kill-statistics",
  },
  selection_box = {{-1, -1}, {1, 1}},
  collision_box = {{-0.65, -0.65}, {0.65, 0.65}},
  collision_mask = {"layer-13"},--"not-colliding-with-itself"},

  item_slot_count = MC_SAVESLOTS,
  sprites =
  {
      north = empty_picture,
      east = empty_picture,
      south = empty_picture,
      west = empty_picture,
  },
})

data:extend{
  imposter_fcpu_item,
  imposter_fcpu
}


local hdl_output_fcpu = table.merge(table.deepcopy(data.raw['constant-combinator']['constant-combinator']), {
  name = "output-fcpu",
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

  item_slot_count = MC_OUTPUT,
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

local hdl_decider_fcpu = table.merge(table.deepcopy(data.raw['decider-combinator']['decider-combinator']), {
  name = "decider-fcpu",
  icon = "__fcpu__/graphics/icons/fcpu.png",
  icon_size = 1,
  icon_mipmaps = 0,
  allow_copy_paste = false,
--  selectable_in_game = false,
--  draw_circuit_wires = false,
  create_ghost_on_death = false,

  energy_source = {
    type = "void",
    usage_priority = "primary-input"
  },

  flags = {
    "not-rotatable",
    "placeable-off-grid",
    "not-repairable",
    "not-on-map",
    "not-blueprintable",
    "not-deconstructable", -- can't be deconstructed by 'demolition blueprint'. reducing bounds marker spam
    --"hidden",
    --"hide-alt-info",
    "not-flammable",
    "not-in-kill-statistics",
  },
  collision_mask = {"not-colliding-with-itself"},
--[[
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
--]]
})

local hdl_arithmetic_fcpu = table.merge(table.deepcopy(data.raw['arithmetic-combinator']['arithmetic-combinator']), {
  name = "arithmetic-fcpu",
  icon = "__fcpu__/graphics/icons/fcpu.png",
  icon_size = 1,
  icon_mipmaps = 0,
  allow_copy_paste = false,
--  selectable_in_game = false,
--  draw_circuit_wires = false,
  create_ghost_on_death = false,

  energy_source = {
    type = "void",
    usage_priority = "primary-input"
  },

  flags = {
    "not-rotatable",
    "placeable-off-grid",
    "not-repairable",
    "not-on-map",
    "not-blueprintable",
    "not-deconstructable", -- can't be deconstructed by 'demolition blueprint'. reducing bounds marker spam
--    "hidden",
--    "hide-alt-info",
    "not-flammable",
    "not-in-kill-statistics",
  },
  collision_mask = {"not-colliding-with-itself"},
--[[
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
--]]
})

data:extend{
  hdl_output_fcpu,
  hdl_decider_fcpu,
  hdl_arithmetic_fcpu,
}