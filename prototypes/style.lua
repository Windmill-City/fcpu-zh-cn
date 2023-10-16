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
  word_wrap = false,
  padding = 0,
}

default_gui["fcpu_breakpoint_label"] = {
  type = "label_style",
  parent = "label",
  rich_text_setting = "enabled",
  single_line = true,
  font='fcpu-mono-small',
  --font='default-small',
  top_padding=0,
  bottom_padding=0,
  horizontal_align='right',
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

default_gui["fcpu_scalar_cell"] = {
  type = "button_style",
  parent = "slot_button_in_shallow_frame",
}

default_gui["fcpu_channel_empty_cell"] = {
  type = "button_style",
  parent = "inventory_slot",
}

default_gui["fcpu_channel_cell"] = {
  type = "button_style",
  parent = "inventory_slot",
}

default_gui["fcpu_channel_cell_ro"] = {
  type = "button_style",
  parent = "yellow_inventory_slot",
}

default_gui["fcpu_channel_cell_indexed"] = {
  type = "button_style",
  parent = "filter_inventory_slot",
}
