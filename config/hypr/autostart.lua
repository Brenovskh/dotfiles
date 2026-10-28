-- Extra autostart processes.
-- o.launch_on_start("my-service")

-- quickshell-dots bar (HANCORE). Was previously started manually / by the
-- installer with no persistent autostart entry anywhere on this system, so
-- it did not survive logout/reboot. Wired here through the officially
-- supported user autostart hook.
o.launch_on_start("qs -n -p " .. os.getenv("HOME") .. "/.config/quickshell/bar/shell.qml")
