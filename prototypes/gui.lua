require('src/constants')

data:extend{
  {
    type = "custom-input",
    name = "fcpu-open",
    key_sequence = "",
    linked_game_control = "open-gui",
  },
  {
    type = "custom-input",
    name = "fcpu-close",
    key_sequence = "",
    linked_game_control = "close-gui",
  },
  {
    type = "custom-input",
    name = "fcpu-escape",
    key_sequence = "",
    linked_game_control = "toggle-menu",
  },
  {
    type = "font",
    name = "fcpu-mono",
    from = "fcpu-mono",
    size = 14
  },
  {
    type = "font",
    name = "fcpu-mono-small",
    from = "fcpu-mono",
    size = 13
  },
}


data:extend{
  {
    type = "sprite",
    name = "fcpu-play-sprite",
    filename = "__fcpu__/graphics/icons/gui/play.png",
    width = 32,
    height = 32
  },
  {
    type = "sprite",
    name = "fcpu-stop-sprite",
    filename = "__fcpu__/graphics/icons/gui/stop.png",
    width = 32,
    height = 32
  },
  {
    type = "sprite",
    name = "fcpu-pause-sprite",
    filename = "__fcpu__/graphics/icons/gui/pause.png",
    width = 32,
    height = 32
  },
  {
    type = "sprite",
    name = "fcpu-next-sprite",
    filename = "__fcpu__/graphics/icons/gui/next.png",
    width = 32,
    height = 32
  },
  {
    type = "sprite",
    name = "fcpu-copy-sprite",
    filename = "__base__/graphics/icons/shortcut-toolbar/mip/copy-x24.png",
    width = 24,
    height = 24
  },
  {
    type = "sprite",
    name = "fcpu-paste-sprite",
    filename = "__base__/graphics/icons/shortcut-toolbar/mip/paste-x24.png",
    width = 24,
    height = 24
  },
  {
    type = "sprite",
    name = "fcpu-memory-sprite",
    filename = "__core__/graphics/icons/mip/grid-view.png",
    x = 0,
    y = 0,
    width = 32,
    height = 32
  },
}
--[[
data:extend{
  {
    type = "sprite",
    name = "fcpu-breakpoint-empty",
    filename = "__core__/graphics/empty.png",
    flags = {'gui'},
    x = 0,
    y = 0,
    width = 1,
    height = 1,
  },
  {
    type = "sprite",
    name = "fcpu-breakpoint-current",
    filename = "__core__/graphics/icons/mip/expand.png",
    flags = {'gui'},
    x = 0,
    y = 0,
    width = 32,
    height = 32,
    scale = 0.25
  },
  {
    type = "sprite",
    name = "fcpu-breakpoint-on",
    filename = "__base__/graphics/icons/list-dot.png",
    flags = {'gui'},
    tint = {r=1, g=0.3, b=0.3, a=1},
    x = 64,
    y = 0,
    width = 32,
    height = 32,
    scale = 0.25
  },
  {
    type = "sprite",
    name = "fcpu-breakpoint-error",
    filename = "__core__/graphics/icons/mip/not-available.png",
    flags = {'gui'},
    x = 0,
    y = 0,
    width = 32,
    height = 32,
    scale = 0.25
  },
}
]]
