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
    linked_game_control = "confirm-gui",
  },
  {
    type = "custom-input",
    name = "fcpu-escape",
    key_sequence = "",
    linked_game_control = "toggle-menu",
  },
}

data:extend{
  {
    type = "custom-input",
    name = "fcpu-debug-stop",
    key_sequence = "SHIFT + F5",
    consuming = "game-only",
  },
  {
    type = "custom-input",
    name = "fcpu-debug-start",
    key_sequence = "F5",
    consuming = "game-only",
  },
  {
    type = "custom-input",
    name = "fcpu-debug-restart",
    key_sequence = "CONTROL + SHIFT + F5",
    consuming = "game-only",
  },
  {
    type = "custom-input",
    name = "fcpu-debug-pause",
    key_sequence = "F6",
    consuming = "game-only",
  },
  {
    type = "custom-input",
    name = "fcpu-debug-step-over",
    key_sequence = "F10",
    alternative_key_sequence = "F8",
    consuming = "game-only",
  },
  {
    type = "custom-input",
    name = "fcpu-debug-step-into",
    key_sequence = "F11",
    alternative_key_sequence = "SHIFT + F7",
    consuming = "game-only",
  },
}
