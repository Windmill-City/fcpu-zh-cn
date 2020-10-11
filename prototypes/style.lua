local default_gui = data.raw["gui-style"].default

default_gui["fcpu_notice_textbox"] = {
  type = "textbox_style",
  parent = "textbox",
  graphical_set =
  {
    type = "none",
    opacity = 0
  },
  font = "fcpu-mono",
  font_color={r=0.8, g=0.9, b=0.8},
  minimal_width=40,
  maximal_width=40,
  minimal_height = 2568,
  maximal_height = 2568,
  padding = 0,
}

default_gui["fcpu_program_input"] = {
  type = "textbox_style",
  parent = "textbox",
  graphical_set =
  {
    type = "none",
    opacity = 0
  },
  font = "fcpu-mono",
  selection_font_color = {r=1, g=1, b=1},
  selection_background_color = {r=0.3, g=0.3, b=0.3},
  minimal_width = 280,
  maximal_width = 300,
  minimal_height = 2568,
  maximal_height = 2568,
  word_wrap = false,
  padding = 0,
}

default_gui["fcpu_toolbar_copy"] = {
  type = "button_style",
  parent = "shortcut_bar_button_small",
  hovered_graphical_set = default_gui["slot_sized_button_green"].hovered_graphical_set,
  clicked_graphical_set = default_gui["slot_sized_button_green"].clicked_graphical_set,
}

default_gui["fcpu_toolbar_paste"] = {
  type = "button_style",
  parent = "shortcut_bar_button_small",
  hovered_graphical_set = default_gui["slot_sized_button_red"].hovered_graphical_set,
  clicked_graphical_set = default_gui["slot_sized_button_red"].clicked_graphical_set,
}
