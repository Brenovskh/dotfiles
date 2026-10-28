-- ~/.config/hypr/bindings.lua
-- Só o que difere do padrão do Omarchy. Tudo que já é default
-- (Terminal, Browser, File manager, ChatGPT, Signal, etc.) NÃO
-- entra aqui -- já está ativo via default.hypr.omarchy.

-- Senhas: keepassxc no lugar do 1Password padrão.
-- SUPER + / era "Monitor scaling up" (zoom da tela) no padrão do Omarchy;
-- removido aqui pois já existe outro bind para zoom.
hl.unbind("SUPER + Slash")
hl.unbind("SUPER + SHIFT + Slash")
o.bind("SUPER + Slash", "Passwords", "uwsm-app -- keepassxc")

-- ---------- Apps Pessoais (reaproveitando teclas do padrao) ----------
hl.unbind("SUPER + SHIFT + E")
o.bind("SUPER + SHIFT + E", "Anki", "gtk-launch anki")

hl.unbind("SUPER + SHIFT + C")
o.bind("SUPER + SHIFT + C", "Kleopatra", "kleopatra")

hl.unbind("SUPER + SHIFT + S")
o.bind("SUPER + SHIFT + S", "Sparrow", "sparrow")

hl.unbind("SUPER + SHIFT + D")
o.bind("SUPER + SHIFT + D", "Discord", "discord")

hl.unbind("SUPER + SHIFT + Y")
o.bind("SUPER + SHIFT + Y", "CloudOTP", "/home/swanzax/Applications/CloudOTP/CloudOTP")

-- SUPER + SHIFT + P era "Google Photos" (webapp) no padrão do Omarchy;
-- substituído aqui pelo Ventic.
hl.unbind("SUPER + SHIFT + P")
o.bind("SUPER + SHIFT + P", "Ventic", "/home/swanzax/Applications/Ventic.AppImage")

-- SUPER + SHIFT + SPACE era "Toggle top bar" (omarchy-toggle-bar) no padrão
-- do Omarchy; removido pois a barra padrão fica sempre desligada (bar-off) —
-- a barra em uso é o quickshell-dots.
hl.unbind("SUPER + SHIFT + SPACE")

-- Sem conflito conhecido com o padrao (testar; se duplicar, mandar
-- 'hyprctl binds | grep -B2 "SUPER SHIFT V"' / "...T" / "...Z")
o.bind("SUPER + SHIFT + V", "VeraCrypt", "veracrypt")
o.bind("SUPER + SHIFT + T", "Tor Browser", "tor-browser")
o.bind("SUPER + SHIFT + Z", "Log Out", "hyprctl dispatch exit")

-- SUPER+W fecha educadamente (respeita apps que minimizam pro tray,
-- tipo Telegram/Ventic). SUPER+ALT+W mata o processo de verdade.
-- (hyprctl dispatch killactive nao existe mais nesse fork Lua do
-- Hyprland do Omarchy -- por isso o script em vez de dispatch nativo)
o.bind("SUPER + ALT + W", "Force Quit", "bash ~/.config/hypr/scripts/force-quit.sh")

o.bind("SUPER + SHIFT + L", "Claude Code", { tui = "claude" })

-- SUPER + CTRL + W era "Network" do padrão, mas abre o painel da barra
-- padrão (oculta, bar-off) -- aqui abre o painel de rede do quickshell-dots.
hl.unbind("SUPER + CTRL + W")
o.bind("SUPER + CTRL + W", "Network", "qs -p " .. os.getenv("HOME") .. "/.config/quickshell/bar/shell.qml ipc call panel network")
