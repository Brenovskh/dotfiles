-- ~/.config/hypr/input.lua
-- Convertido de input.conf (Omarchy 3.8 -> Quattro)

hl.config({
  input = {
    kb_layout = "us,ru",
    kb_options = "compose:caps,grp:alt_shift_toggle",
    repeat_rate = 40,
    repeat_delay = 250,
    numlock_by_default = true,
    touchpad = {
      clickfinger_behavior = true,
      scroll_factor = 0.4,
    },
  },
})

-- App-specific touchpad scroll speeds
o.window("(Alacritty|kitty|foot)", { scroll_touchpad = 1.5 })
o.window("com.mitchellh.ghostty", { scroll_touchpad = 0.2 })
