# =========================
# ⚡ PERFORMANCE / INIT
# =========================
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# =========================
# ⚡ ZINIT
# =========================
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

if [ ! -d "$ZINIT_HOME" ]; then
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

source "${ZINIT_HOME}/zinit.zsh"

# =========================
# ⚡ PLUGINS
# =========================
zinit ice depth=1; zinit light romkatv/powerlevel10k

zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light zdharma-continuum/fast-syntax-highlighting

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# =========================
# ⚡ COMPLETION
# (cache de 24h: evita recalcular a cada shell)
# =========================
autoload -Uz compinit
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# =========================
# ⚡ HISTÓRICO
# =========================
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

# appendhistory removido: inc_append_history já cobre
setopt sharehistory
setopt hist_ignore_dups
setopt hist_ignore_space
setopt hist_verify
setopt inc_append_history

# =========================
# ⚡ QUALIDADE DE VIDA
# =========================
setopt autocd
setopt extendedglob
setopt notify
setopt INTERACTIVE_COMMENTS

# =========================
# ⚡ KEYBINDS
# =========================
bindkey -e

# Busca no histórico pelo que já digitou (seta ↑↓)
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# Editar comando longo no Neovim (Ctrl+X Ctrl+E)
autoload -U edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# =========================
# ⚡ PATH / ENV
# =========================
export PATH="$HOME/.local/bin:$PATH"
export MOZ_ENABLE_WAYLAND=1

# =========================
# ⚡ ALIASES
# =========================
alias compare='python3 ~/compare_text.py'

# Baixar áudio em MP3 (qualidade máxima, sem playlist, sem sobrescrever)
alias ytmp3='yt-dlp -x --audio-format mp3 --audio-quality 0 --embed-metadata --embed-thumbnail --no-playlist --no-overwrites --continue -o "%(title).200B [%(id)s].%(ext)s"'

# Baixar vídeo em MP4 até 1440p
alias ytmp4k='yt-dlp -f "bv*[height<=1440]+ba/b[height<=1440]" --merge-output-format mp4 --embed-metadata --embed-thumbnail -o "%(upload_date>%Y-%m-%d)s - %(title).200B [%(id)s].%(ext)s"'
# Igual ao ytmp4k, mas com os cookies do Waterfox (vídeos members-only)
alias ytmp4km='ytmp4k --cookies-from-browser "firefox:/home/swanzax/.waterfox/m5lhrh8a.default-release"'

# Atalhos gerais
alias v='nvim'
alias vim='nvim'
alias conf='cd ~/.config'
alias hypr-reload='hyprctl reload'
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias warp-on="sudo systemctl start warp-svc && sleep 2 && warp-cli connect"
alias warp-off="warp-cli disconnect && sudo systemctl stop warp-svc"
# =========================
# ⚡ FUNÇÕES
# =========================

# Baixar playlist do Spotify em MP3
spotdl-pl() {
    spotdl download "$1" \
        --format mp3 \
        --bitrate 320k \
        --audio youtube-music youtube piped \
        --lyrics synced azlyrics \
        --generate-lrc \
        --overwrite skip \
        --restrict strict \
        --threads 4 \
        --max-retries 3 \
        --output "$HOME/Music/Playlists/{list-name}/{artists} - {title}"
}

# mkdir + cd combinados
mkcd() {
  mkdir -p "$1" && cd "$1"
}

# Extrair qualquer arquivo comprimido
extract() {
  if [ -f "$1" ]; then
    case "$1" in
      *.tar.gz)  tar xzf "$1"  ;;
      *.tar.bz2) tar xjf "$1"  ;;
      *.tar.xz)  tar xf "$1"   ;;
      *.tar)     tar xf "$1"   ;;
      *.gz)      gunzip "$1"   ;;
      *.zip)     unzip "$1"    ;;
      *.rar)     unrar x "$1"  ;;
      *.7z)      7z x "$1"     ;;
      *)         echo "Formato não suportado: $1" ;;
    esac
  else
    echo "Arquivo não encontrado: $1"
  fi
}
