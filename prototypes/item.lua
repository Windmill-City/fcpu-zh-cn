data:extend{
  table.merge(table.deepcopy(data.raw['arithmetic-combinator']['arithmetic-combinator']), {
    name = "fcpu",
    minable = {hardness = 0.2, mining_time = 0.5, result = "fcpu"},
    active_energy_usage = "20KW",
    selection_box = {{-1, -1}, {1, 1}},
    additional_pastable_entities = {"fcpu", "arithmetic-combinator", "decider-combinator"},
  }),
  {
    type = "item",
    name = "fcpu",
    place_result = 'fcpu',
    icon = "__fcpu__/graphics/icons/fcpu.png",
    icon_size = 64,
    stack_size = 20,
    subgroup = "circuit-network"
  },
  {
    type = "recipe",
    name = "fcpu",
    ingredients = {{"arithmetic-combinator", 10}, {"decider-combinator", 10}, {"processing-unit", 1}},
    energy_required = 20,
    results = {{"fcpu", 1}}
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
  }
}