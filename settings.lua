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
    type = "string-setting",
    name = "fcpu-debug-enabled",
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
  }
})
