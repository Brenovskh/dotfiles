#!/usr/bin/env bash
# Copia as configs do sistema para este repositório (nunca o contrário).
set -euo pipefail
cd "$(dirname "$0")"
C=~/.config

rs() { rsync -a --delete --exclude='*.bak*' --exclude='.git' "$@"; }

mkdir -p config bin systemd/user
for d in hypr nvim foot kitty quickshell btop mpv tmux voxtype wireplumber environment.d fontconfig; do
  [ -d "$C/$d" ] && rs "$C/$d/" "config/$d/"
done
cp "$C/starship.toml" config/

# omarchy: só configs/hooks próprios (temas e plugins são de terceiros e pesados)
rs --exclude='themes' --exclude='plugins' --exclude='*.sample' --exclude='*.sample/' "$C/omarchy/" config/omarchy/

# serviços systemd do usuário (sem os links de enable)
rsync -a --delete --include='*.service' --include='*.timer' --exclude='*' "$C/systemd/user/" systemd/user/

# scripts próprios de ~/.local/bin (shims do mise ficam de fora)
for f in claude-usage clean-ytsrt mic-on fix-mic-mute.sh omarchy-screensaver-bridge omarchy-launch-webapp \
         qs-arch-apply-update.sh qs-arch-security-gate.sh qs-arch-update-check.sh qs-aur-blacklist-fetch.sh \
         qs-proj syncleg waybar-clock-theme-sync.sh; do
  [ -f ~/.local/bin/$f ] && cp ~/.local/bin/$f bin/
done

cp ~/.zshrc zshrc
cp ~/.bashrc bashrc
cp ~/.p10k.zsh p10k.zsh
