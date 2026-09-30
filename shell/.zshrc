# =========================================
# SHELL HISTORY & INTERACTIVE BEHAVIOUR
# =========================================

HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

bindkey -e

unsetopt CORRECT
unsetopt NOMATCH

# Machine-identifying prompt.
# ComputerName is read when each shell starts so this configuration
# can remain identical across both Macs.
MAC_NAME="$(scutil --get ComputerName 2>/dev/null || hostname -s)"

PROMPT="[$MAC_NAME | %n]
%# "

# =========================================
# PATH DEDUPLICATION
# =========================================

typeset -U path PATH

# =========================================
# COMPLETION & PASTE HANDLING
# =========================================

autoload -Uz bracketed-paste-url-magic
zle -N bracketed-paste bracketed-paste-url-magic

autoload -Uz url-quote-magic
zle -N self-insert url-quote-magic

autoload -Uz compinit
if [[ -f "$HOME/.zcompdump" ]]; then
  compinit -C
else
  compinit
fi

# =========================================
# ENVIRONMENT WORKSPACES
# =========================================

load_envrc() {
  if [[ -f .envrc ]]; then
    source .envrc
  fi
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd load_envrc
load_envrc

# =========================================
# SYSTEM & DEVELOPMENT UTILITIES
# =========================================

[[ -x "$HOME/fixram.sh" ]] &&
  alias fixram="$HOME/fixram.sh"

[[ -x "$HOME/memory_diagnostic.sh" ]] &&
  alias memdiag="$HOME/memory_diagnostic.sh"

[[ -x "$HOME/check_dev_tools.sh" ]] &&
  alias checkdev="$HOME/check_dev_tools.sh"

[[ -x "$HOME/assess_dev_upgrades.sh" ]] &&
  alias devrisk="$HOME/assess_dev_upgrades.sh"

[[ -x "$HOME/startwork.sh" ]] &&
  alias startwork="$HOME/startwork.sh"

[[ -x "$HOME/finishwork.sh" ]] &&
  alias finishwork="$HOME/finishwork.sh"

# =========================================
# MACHINE IDENTITY
# =========================================

macid() {
  echo "ComputerName  : $(scutil --get ComputerName 2>/dev/null || echo 'Not set')"
  echo "LocalHostName : $(scutil --get LocalHostName 2>/dev/null || echo 'Not set')"
  echo "HostName      : $(scutil --get HostName 2>/dev/null || echo 'Not set')"
  echo "User          : $(whoami)"
  echo "Architecture  : $(uname -m)"
  echo "Shell         : $SHELL"
}

# =========================================
# CLOUD STORAGE UTILITIES
# =========================================

c_store="$HOME/Library/CloudStorage"

cleanlocks() {
  find "$c_store" -type f \
    \( -name '~lock.*' -o -name '~$*' \) \
    -delete
  echo "Cloud locks purged."
}

# =========================================
# NETWORK UTILITIES
# =========================================

netcheck() {
  local ip_t="https://1.1.1.1"
  local dns_t="https://apple.com"

  echo -n "Routing (IP): "
  if curl -sI "$ip_t" --max-time 2 >/dev/null; then
    echo "OK"
  else
    echo "FAIL"
  fi

  echo -n "DNS Lookup:   "
  if curl -sI "$dns_t" --max-time 2 >/dev/null; then
    echo "OK"
  else
    echo "FAIL"
  fi
}

# =========================================
# MEDIA ARCHIVAL & EXTRACTION
# =========================================

unalias fetdl 2>/dev/null || true

fetdl() {
  local u="$1"

  if [[ -z "$u" ]]; then
    echo "Usage: fetdl <URL>"
    return 1
  fi

  local d="$HOME/Downloads"
  local id=""
  local ref=""
  local out=""

  mkdir -p "$d"

  if [[ "$u" =~ fetlife\.com/([0-9]+)/ ]]; then
    id="${match[1]}"
    ref="https://fetlife.com/"
    out="$d/fetlife_${id}.mp4"
  else
    id="$(echo -n "$u" | md5 | cut -c1-8)"
    out="$d/video_${id}.mp4"
  fi

  local dl_args=(
    --force-overwrites
    -f "bestvideo+bestaudio/best"
    -N 4
    "$u"
    -o "$out"
  )

  if [[ -n "$ref" ]]; then
    dl_args=(
      --referer "$ref"
      "${dl_args[@]}"
    )
  fi

  yt-dlp "${dl_args[@]}" || return 1

  if [[ -f "$out" ]]; then
    ffprobe -v error -show_format -show_streams "$out" >/dev/null 2>&1
    ffmpeg -v error -i "$out" -f null - 2>&1
    open -R "$out"
  fi
}

alias fetdl="noglob fetdl"

# =========================================
# NODE VERSION MANAGER
# =========================================

export NVM_DIR="$HOME/.nvm"

if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  source "$NVM_DIR/nvm.sh"
fi

if [[ -s "$NVM_DIR/bash_completion" ]]; then
  source "$NVM_DIR/bash_completion"
fi

# =========================================
# TERMINAL INTEGRATIONS
# =========================================

if [[ -e "$HOME/.iterm2_shell_integration.zsh" ]]; then
  source "$HOME/.iterm2_shell_integration.zsh"
fi

# =========================================
# WARP MACHINE IDENTITY FOOTER
# =========================================
# Warp uses its own block UI and may suppress the normal Zsh prompt.
# Print a compact machine identifier after each command in Warp only.

warp_machine_identity() {
  if [[ "${TERM_PROGRAM:-}" == "WarpTerminal" ]] || [[ -n "${WARP_IS_LOCAL_SHELL_SESSION:-}" ]]; then
    local machine
    machine="$(scutil --get ComputerName 2>/dev/null || hostname -s)"
    print
    print "[$machine | $(whoami)]"
  fi
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd warp_machine_identity
