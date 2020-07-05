table = require('__stdlib__/stdlib/utils/table')

require('prototypes/style')
require('prototypes/gui')
require('prototypes/item')


data:extend{
  {
      type = "virtual-signal",
      name = "signal-fcpu-halt",
      icon = "__fcpu__/graphics/icons/signal_halt.png",
      icon_size = 32,
      subgroup = "virtual-signal-letter",
      order = "d[fcpu]-[A]"
  },
  {
      type = "virtual-signal",
      name = "signal-fcpu-run",
      icon = "__fcpu__/graphics/icons/signal_run.png",
      icon_size = 32,
      subgroup = "virtual-signal-letter",
      order = "d[fcpu]-[B]"
  },
  {
      type = "virtual-signal",
      name = "signal-fcpu-step",
      icon = "__fcpu__/graphics/icons/signal_step.png",
      icon_size = 32,
      subgroup = "virtual-signal-letter",
      order = "d[fcpu]-[C]"
  },
  {
      type = "virtual-signal",
      name = "signal-fcpu-sleep",
      icon = "__fcpu__/graphics/icons/signal_sleep.png",
      icon_size = 32,
      subgroup = "virtual-signal-letter",
      order = "d[fcpu]-[D]"
  },
  {
      type = "virtual-signal",
      name = "signal-fcpu-jump",
      icon = "__fcpu__/graphics/icons/signal_jump.png",
      icon_size = 32,
      subgroup = "virtual-signal-letter",
      order = "d[fcpu]-[E]"
  },
}
