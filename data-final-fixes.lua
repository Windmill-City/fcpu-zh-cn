-- 开启「紧凑尺寸」设置时，把程控运算器的占地从 2x2 改成 2x1。
if settings.startup["fcpu-zh-cn-compact-size"].value then
  local fcpu = data.raw["arithmetic-combinator"] and data.raw["arithmetic-combinator"]["fcpu"]
  if fcpu then
    fcpu.collision_box = {{-0.325, -0.65}, {0.325, 0.65}}
    fcpu.selection_box = {{-0.5, -1}, {0.5, 1}}
  end
end
