-- 维基缩略图直接引用 fCPU 自带的 thumbnail.png，
-- 图片本体不打包进本模组，运行时从 fCPU 模组目录加载。
-- 与 fCPU 原版一致：注册一个 145x145 的 button_style，
-- 通过 button 元素显示大图（sprite-button 会退化为默认小图标）。
local thumbnail_set = {
  filename = "__fcpu__/thumbnail.png",
  scale = 1,
  width = 145,
  height = 145,
}

data.raw["gui-style"]["default"]["fcpu-zh-cn-thumbnail"] = {
  type = "button_style",
  width = 145,
  height = 145,
  default_graphical_set = thumbnail_set,
  hovered_graphical_set = thumbnail_set,
  clicked_graphical_set = thumbnail_set,
  disabled_graphical_set = thumbnail_set,
}
