#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  waybar-clock-theme-sync.sh
#  Sincroniza as cores do clock.json com o tema
#  atual do Omarchy. Rode após trocar de tema.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

WAYBAR_CSS="$HOME/.config/omarchy/current/theme/waybar.css"
CLOCK_JSON="$HOME/.config/waybar/dcol_modules/clock.json"

# Fallback se o clock.json estiver em outro lugar
if [ ! -f "$CLOCK_JSON" ]; then
    CLOCK_JSON="$HOME/.config/waybar/clock.json"
fi

if [ ! -f "$WAYBAR_CSS" ]; then
    echo "Erro: $WAYBAR_CSS não encontrado."
    exit 1
fi

if [ ! -f "$CLOCK_JSON" ]; then
    echo "Erro: clock.json não encontrado em $CLOCK_JSON"
    echo "Ajuste a variável CLOCK_JSON no script."
    exit 1
fi

# Extrai as cores do tema atual
BG=$(grep '@define-color background' "$WAYBAR_CSS" | awk '{print $3}' | tr -d ';')
FG=$(grep '@define-color foreground' "$WAYBAR_CSS" | awk '{print $3}' | tr -d ';')

if [ -z "$BG" ] || [ -z "$FG" ]; then
    echo "Erro: não foi possível extrair as cores de $WAYBAR_CSS"
    exit 1
fi

echo "Tema detectado → background: $BG  foreground: $FG"

# Reescreve o clock.json com as cores atuais
cat > "$CLOCK_JSON" << JSONEOF
{
    "clock": {
        "format": "{:%R  •  %a %d %b}",
        "tooltip-format": "<big><b>{:%B %Y}</b></big>\n<tt><small>{calendar}</small></tt>",
        "on-click": "bash -c 'gnome-calendar || calcurse || io.elementary.calendar'",

        "calendar": {
            "mode": "month",
            "mode-mon-col": 3,
            "weeks-pos": "right",
            "on-scroll": 1,
            "on-click-right": "mode",
            "format": {
                "months":   "<span foreground='$FG'><b>{}</b></span>",
                "days":     "<span foreground='$FG'>{}</span>",
                "weekdays": "<span foreground='$FG' alpha='65%'><b>{}</b></span>",
                "today":    "<span foreground='$BG' bgcolor='$FG'><b>{}</b></span>"
            }
        },

        "actions": {
            "on-click-right": "mode",
            "on-scroll-up": "shift_up",
            "on-scroll-down": "shift_down"
        }
    }
}
JSONEOF

echo "clock.json atualizado com sucesso."

# Reinicia o Waybar
if pgrep -x waybar > /dev/null; then
    pkill waybar
    sleep 0.5
    nohup waybar > /dev/null 2>&1 &
    echo "Waybar reiniciado."
fi
