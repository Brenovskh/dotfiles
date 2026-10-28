#!/usr/bin/env bash
# Mata de verdade a janela focada (processo + filhos), pra apps tipo
# Telegram/Ventic que interceptam o close educado e ficam vivos no tray.
set -euo pipefail

win=$(hyprctl activewindow -j)
pid=$(jq -r '.pid // empty' <<<"$win")
[ -z "$pid" ] && exit 0

class=$(jq -r '.class // empty' <<<"$win")
case "$class" in
  foot|Alacritty|kitty|org.wezfurlong.wezterm|com.mitchellh.ghostty|org.omarchy.*)
    notify-send "Force Quit" "Bloqueado: '$class' é um terminal, use o comando do proprio shell." 2>/dev/null || true
    exit 0
    ;;
esac

# NUNCA matar por process group (PGID): alguns apps (ex.: Ventic) sao
# lancados sem setsid proprio e acabam herdando o mesmo PGID do
# Hyprland/quickshell/voxtype -- um kill de grupo mataria a sessao
# inteira (foi exatamente o que aconteceu em 2026-09-20: SUPER+ALT+W
# no Ventic matou o Hyprland e derrubou todos os apps de uma vez).
# Em vez disso, percorre a arvore de processos a partir do PID focado
# e mata so o processo + descendentes.
collect_tree() {
  local p="$1"
  echo "$p"
  local child
  for child in $(pgrep -P "$p" 2>/dev/null); do
    collect_tree "$child"
  done
}

pids=$(collect_tree "$pid" | sort -un)

# Trava de seguranca extra: aborta se por algum motivo o Hyprland
# aparecer na arvore coletada (nao deveria, ja que so descemos a
# partir do pid focado -- mas o custo de checar e minimo).
hypr_pid=$(pgrep -x Hyprland | head -n1 || true)
if [ -n "$hypr_pid" ] && grep -qx "$hypr_pid" <<<"$pids"; then
  notify-send "Force Quit" "Abortado: alvo incluiria o Hyprland. Cancelado por seguranca." 2>/dev/null || true
  exit 1
fi

# shellcheck disable=SC2086
kill -9 $pids 2>/dev/null || true
