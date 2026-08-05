-- 维基缩略图直接引用 fCPU 自带的 thumbnail.png，
-- 图片本体不打包进本模组，运行时从 fCPU 模组目录加载。
data:extend({
  {
    type = "sprite",
    name = "fcpu-zh-cn-thumbnail",
    filename = "__fcpu__/thumbnail.png",
    width = 145,
    height = 145,
    scale = 1.0
  }
})
