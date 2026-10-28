-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })

-- OCR text capture (omarchy capture text) reads OMARCHY_OCR_LANGS to decide
-- which Tesseract language data to use. Default is "eng" only; add "rus" so
-- Cyrillic (Russian) text can be extracted too. Tesseract auto-detects which
-- of the listed languages applies per selection.
hl.env("OMARCHY_OCR_LANGS", "eng+rus")

-- Prevent applications started by background processes from opening on workspace 1
hl.config({
  misc = {
    initial_workspace_tracking = 0,
  },
})

-- Fully opaque windows everywhere (Omarchy default is 0.985 active / 0.96
-- inactive, and its browser rule doesn't match Waterfox).
o.window(".*", { opacity = "1 1" })
