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

# =========================================
# SHELL CONFIGURATION SYNC
# =========================================

shellsync() {
  local action="${1:-status}"
  local repo="$HOME/.dotfiles"
  local shell_dir="$repo/shell"
  local script_dir="$shell_dir/scripts"
  local machine
  local stamp
  local backup_dir
  local ahead
  local behind
  local answer

  machine="$(scutil --get ComputerName 2>/dev/null || hostname -s)"
  stamp="$(date +%Y%m%d-%H%M%S)"

  echo "============================================================"
  echo "SHELLSYNC"
  echo "Machine : $machine"
  echo "Action  : $action"
  echo "============================================================"

  if [[ ! -d "$repo/.git" ]]; then
    echo "STOP: $repo is not a Git repository."
    return 1
  fi

  git -C "$repo" fetch origin || return 1

  read ahead behind <<< "$(git -C "$repo" rev-list --left-right --count HEAD...origin/main)"

  case "$action" in

    status)
      echo
      echo "=== REPOSITORY ==="
      echo "Branch : $(git -C "$repo" branch --show-current)"
      echo "HEAD   : $(git -C "$repo" rev-parse --short HEAD)"
      echo "Remote : $(git -C "$repo" rev-parse --short origin/main)"
      echo "Ahead  : $ahead"
      echo "Behind : $behind"

      echo
      echo "=== LIVE VS REPOSITORY ==="

      for f in .zshenv .zprofile .zshrc; do
        if cmp -s "$HOME/$f" "$shell_dir/$f"; then
          echo "$f : IDENTICAL"
        else
          echo "$f : DIFFERENT"
        fi
      done

      for f in fixram.sh memory_diagnostic.sh; do
        if cmp -s "$HOME/$f" "$script_dir/$f"; then
          echo "$f : IDENTICAL"
        else
          echo "$f : DIFFERENT"
        fi
      done

      echo
      echo "=== REPOSITORY STATUS ==="
      git -C "$repo" status --short
      ;;

    pull)
      if [[ -n "$(git -C "$repo" status --porcelain)" ]]; then
        echo
        echo "STOP: Repository has uncommitted changes."
        git -C "$repo" status --short
        return 1
      fi

      echo
      echo "=== UPDATE REPOSITORY ==="
      git -C "$repo" pull --ff-only || return 1

      echo
      echo "=== VALIDATE CANONICAL CONFIG ==="

      for f in .zshenv .zprofile .zshrc; do
        if /bin/zsh -n "$shell_dir/$f"; then
          echo "PASS: $f"
        else
          echo "FAIL: $f"
          return 1
        fi
      done

      backup_dir="$HOME/.zsh-backups/shellsync-$stamp"
      mkdir -p "$backup_dir"

      echo
      echo "=== BACKUP CURRENT LIVE CONFIG ==="

      for f in .zshenv .zprofile .zshrc; do
        if [[ -f "$HOME/$f" ]]; then
          cp -p "$HOME/$f" "$backup_dir/$f"
          echo "Backed up: $f"
        fi
      done

      echo
      echo "=== INSTALL SHARED CONFIG ==="

      for f in .zshenv .zprofile .zshrc; do
        cp -p "$shell_dir/$f" "$HOME/$f" || return 1
        echo "Installed: $f"
      done

      # These two are deliberately common to both Macs.
      for f in fixram.sh memory_diagnostic.sh; do
        if [[ -f "$script_dir/$f" ]]; then
          cp -p "$script_dir/$f" "$HOME/$f"
          chmod +x "$HOME/$f"
          echo "Installed: $f"
        fi
      done

      echo
      echo "Backup:"
      echo "$backup_dir"

      echo
      echo "PULL COMPLETE"
      echo "Open a new shell, or run: exec zsh -l"
      ;;

    push)
      if (( behind > 0 )); then
        echo
        echo "STOP: GitHub is ahead of this Mac by $behind commit(s)."
        echo "Run: shellsync pull"
        echo "Then review before pushing."
        return 1
      fi

      if (( ahead > 0 )); then
        echo
        echo "STOP: Local repository is already ahead of GitHub by $ahead commit(s)."
        echo "Review the repository before creating another sync commit."
        return 1
      fi

      if [[ -n "$(git -C "$repo" status --porcelain)" ]]; then
        echo
        echo "STOP: Repository already contains uncommitted changes."
        git -C "$repo" status --short
        return 1
      fi

      echo
      echo "=== SNAPSHOT LIVE CONFIG ==="

      mkdir -p "$script_dir"

      for f in .zshenv .zprofile .zshrc; do
        if [[ -f "$HOME/$f" ]]; then
          cp -p "$HOME/$f" "$shell_dir/$f"
          echo "Captured: $f"
        fi
      done

      for f in \
        fixram.sh \
        memory_diagnostic.sh \
        check_dev_tools.sh \
        assess_dev_upgrades.sh \
        startwork.sh \
        finishwork.sh
      do
        if [[ -f "$HOME/$f" ]]; then
          cp -p "$HOME/$f" "$script_dir/$f"
          echo "Captured: $f"
        fi
      done

      echo
      echo "=== SYNTAX CHECK ==="

      for f in .zshenv .zprofile .zshrc; do
        if /bin/zsh -n "$shell_dir/$f"; then
          echo "PASS: $f"
        else
          echo "FAIL: $f"
          echo "No commit has been made."
          return 1
        fi
      done

      echo
      echo "=== CHANGES ==="

      if [[ -z "$(git -C "$repo" status --porcelain)" ]]; then
        echo "No changes to sync."
        return 0
      fi

      git -C "$repo" status --short

      echo
      echo "=== DIFF SUMMARY ==="
      git -C "$repo" diff --stat

      echo
      echo "=== DIFF ==="
      git -C "$repo" diff

      echo
      printf "Commit and push these changes? [y/N] "
      read -r answer

      case "$answer" in
        y|Y|yes|YES)
          ;;
        *)
          echo "Cancelled. Nothing committed or pushed."
          return 0
          ;;
      esac

      git -C "$repo" add shell/ || return 1

      git -C "$repo" commit \
        -m "Sync shell configuration from $machine ($stamp)" || return 1

      git -C "$repo" push origin main || return 1

      echo
      echo "=== SYNC COMPLETE ==="
      git -C "$repo" log -1 --oneline --decorate
      ;;

    *)
      echo
      echo "Usage:"
      echo "  shellsync status"
      echo "  shellsync pull"
      echo "  shellsync push"
      return 1
      ;;
  esac

  echo
  echo "============================================================"
  echo "[$machine | $(whoami)]"
}

