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
    type = "font",
    name = "default-mono",
    from = "default-mono",
    size = 16
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
      name = "fcpu-next-sprite",
      filename = "__fcpu__/graphics/icons/gui/next.png",
      width = 32,
      height = 32
  },
}

for i = 1, MC_LINES do
  local y = ((i-1) * 21)
  if i >= 11 then
      y = y - 1
  end
  local h = 21
  data:extend{
      {
          type = "sprite",
          name = "fcpu-line-sprite-default-"..i,
          filename = "__fcpu__/graphics/icons/gui/lines.png",
          width = 42,
          height = h,
          x = 0,
          y = y
      }
  }
  data:extend{
      {
          type = "sprite",
          name = "fcpu-line-sprite-active-"..i,
          filename = "__fcpu__/graphics/icons/gui/lines.png",
          width = 42,
          height = h,
          x = 42,
          y = y
      }
  }
  data:extend{
      {
          type = "sprite",
          name = "fcpu-line-sprite-error-"..i,
          filename = "__fcpu__/graphics/icons/gui/lines.png",
          width = 42,
          height = h,
          x = 84,
          y = y   
      }
  }
end
