local empty_picture = {
  filename = "__fcpu__/graphics/empty.png",
  x = 0,
  y = 0,
  width = 1,
  height = 1,
  frame_count = 1,
  shift = {0, 0},
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

local imposter_fcpu = table.deep_merge{table.deep_copy(data.raw['constant-combinator']['constant-combinator']), {
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
    --"not-blueprintable",
    --"not-deconstructable", -- can't be deconstructed by 'demolition blueprint'. reducing bounds marker spam
    "hide-alt-info",
    "not-flammable",
    "no-copy-paste",
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
}}

data:extend{
  imposter_fcpu_item,
  imposter_fcpu
}
