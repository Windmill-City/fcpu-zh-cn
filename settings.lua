data:extend({
  {
    type = "int-setting",
    name = "fcpu-gui-updates-every-tick",
    setting_type = "runtime-global",
    default_value = 1,
    minimum_value = 1,
    maximum_value = 60,
    allowed_values = { 1, 2, 5, 10, 20, 30, 60 }
  },
  {
    type = "int-setting",
    name = "fcpu-gui-editor-width",
    setting_type = "runtime-per-user",
    default_value = 290,
    minimum_value = 290,
    maximum_value = 490,
  },
  {
    type = "bool-setting",
    name = "fcpu-gui-editor-autoscroll",
    setting_type = "runtime-per-user",
    default_value = true
  },
  {
    type = "bool-setting",
    name = "fcpu-gui-editor-inline-icons",
    setting_type = "runtime-global",
    default_value = true
  },
  {
    type = "bool-setting",
    name = "fcpu-debug-enabled",
    setting_type = "startup",
    default_value = false
  },
  {
    type = "string-setting",
    name = "fcpu-debug-mode",
    setting_type = "runtime-global",
    default_value = "d",
    allowed_values = { 'd', 'c', 'l', 'b' }
  },
  {
    type = "int-setting",
    name = "fcpu-maximum-updates-per-tick",
    setting_type = "runtime-global",
    default_value = 200,
    minimum_value = 100,
    maximum_value = 1000,
    allowed_values = { 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000 }
  },
  {
    type = "int-setting",
    name = "fcpu-program-lines",
    setting_type = "startup",
    default_value = 256,
    minimum_value = 64,
    maximum_value = 999,
    allowed_values = { 64, 128, 256, 512, 999 }
  }
})
