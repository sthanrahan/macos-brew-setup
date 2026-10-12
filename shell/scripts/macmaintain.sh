#!/bin/bash
set -uo pipefail

REPO="$HOME/.dotfiles"
LOG=$(mktemp "${TMPDIR:-/tmp}/macmaintain.XXXXXX") || exit 1

step() {
  local label="$1" rc
  shift
  printf '\n=== %s ===\n' "$label"
  "$@"
  rc=$?
  printf '%s exit code: %s\n' "$label" "$rc"
  return "$rc"
}

main() {
  local machine ahead behind
  machine=$(/usr/sbin/scutil --get ComputerName) || return 1
  printf 'MAC MAINTENANCE — %s\n' "$machine"
  case "$machine" in
    'Shannon MBP 13 - M1 (2020)') export MAC_ENV_PROFILE=shannon ;;
    'PHL MBP 16 - M1X (2021)') export MAC_ENV_PROFILE=phl ;;
    *) printf 'STOP: Unrecognised machine.\n'; return 1 ;;
  esac
  [[ "$(git -C "$REPO" branch --show-current)" == main ]] || return 1
  [[ -z "$(git -C "$REPO" status --porcelain)" ]] || {
    printf 'STOP: Repository has local changes.\n'; return 1;
  }
  step 'Fetch GitHub' git -C "$REPO" fetch origin || return $?
  read -r ahead behind <<< "$(git -C "$REPO" rev-list --left-right --count HEAD...origin/main)"
  [[ "$ahead" == 0 ]] || {
    printf 'STOP: Review local commits before maintenance.\n'; return 1;
  }
  if [[ "$behind" != 0 ]]; then
    printf 'Incoming changes require the existing guarded sync workflow.\n'
    printf 'Run macsync apply, then run macmaintain again.\n'
    return 1
  fi
  step 'Verify managed files and packages' /bin/bash "$REPO/shell/scripts/macsync.sh" status || return $?
  step 'Update Homebrew' brew update || return $?
  export HOMEBREW_NO_AUTO_UPDATE=1
  step 'Upgrade Homebrew packages' brew upgrade || return $?
  step 'Homebrew health' brew doctor || return $?
  step 'Memory and disk diagnostics' "$HOME/fixram.sh" || return $?
  step 'Safe cleanup' "$HOME/.local/bin/cleanmac" || return $?
  step 'Final alignment verification' /bin/bash "$REPO/shell/scripts/macsync.sh" status || return $?
  printf '\nMaintenance completed successfully.\n'
}

{
  main
  result=$?
  printf '\nMaintenance outcome exit code: %s\n' "$result"
  exit "$result"
} 2>&1 | tee "$LOG"
result=${PIPESTATUS[0]}
if /usr/bin/pbcopy < "$LOG"; then
  printf '\nResults copied to clipboard. Log: %s\n' "$LOG"
else
  printf '\nClipboard copy failed. Log: %s\n' "$LOG"
  [[ "$result" != 0 ]] || result=1
fi
exit "$result"
