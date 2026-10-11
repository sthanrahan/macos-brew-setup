#!/bin/bash
set -euo pipefail

REPO="$HOME/.dotfiles"
ACTION="${1:-status}"
MACHINE=$(/usr/sbin/scutil --get ComputerName)

case "$MACHINE" in
  "Shannon MBP 13 - M1 (2020)") PROFILE=shannon ;;
  "PHL MBP 16 - M1X (2021)") PROFILE=phl ;;
  *) printf 'STOP: Unrecognised machine: %s\n' "$MACHINE"; exit 1 ;;
esac

case "$ACTION" in
  status|apply) ;;
  *) printf 'Usage: macsync status | macsync apply\n'; exit 1 ;;
esac

export MAC_ENV_PROFILE="$PROFILE"
export HOMEBREW_NO_AUTO_UPDATE=1

cd "$REPO"
[[ "$(git branch --show-current)" == main ]] || {
  printf 'STOP: Repository must be on main.\n'
  exit 1
}

git fetch origin
printf '\nMACSYNC — %s\nProfile: %s\n' "$MACHINE" "$PROFILE"
git --no-pager status --short --branch
git --no-pager log -1 --oneline

read -r AHEAD BEHIND <<< \
  "$(git rev-list --left-right --count HEAD...origin/main)"
printf 'Ahead: %s | Behind: %s\n' "$AHEAD" "$BEHIND"

if [[ "$ACTION" == apply ]]; then
  [[ -z "$(git status --porcelain)" ]] || {
    printf 'STOP: Commit or resolve repository changes before applying.\n'
    exit 1
  }
  [[ "$AHEAD" == 0 ]] || {
    printf 'STOP: Review local commits before applying.\n'
    exit 1
  }

  # Preserve live edits: accept only the local or incoming canonical copy.
  for item in .zshenv .zprofile .zshrc fixram.sh memory_diagnostic.sh cleanmac.sh; do
    case "$item" in
      .*) SOURCE="shell/$item"; LIVE="$HOME/$item" ;;
      cleanmac.sh)
        SOURCE="shell/scripts/$item"
        LIVE="$HOME/.local/bin/cleanmac"
        ;;
      *) SOURCE="shell/scripts/$item"; LIVE="$HOME/$item" ;;
    esac
    if [[ -e "$LIVE" || -L "$LIVE" ]]; then
      if ! cmp -s "$LIVE" "$REPO/$SOURCE" &&
         ! git show "origin/main:$SOURCE" | cmp -s "$LIVE" -; then
        printf 'STOP: Unrecorded live edits: %s\n' "$LIVE"
        exit 1
      fi
    fi
  done

  if [[ "$BEHIND" != 0 ]]; then
    printf '\nIncoming repository changes:\n'
    git --no-pager diff --stat HEAD..origin/main
    printf 'Pull these changes before preparing the installation plan? [y/N] '
    read -r ANSWER
    case "$ANSWER" in y|Y|yes|YES) ;; *) exit 1 ;; esac
    git pull --ff-only origin main

    # Use the incoming version of this command.
    exec /bin/bash "$REPO/shell/scripts/macsync.sh" apply
  fi
elif [[ "$BEHIND" != 0 ]]; then
  printf '\nIncoming changes:\n'
  git --no-pager diff --stat HEAD..origin/main
  printf '\nChecks below use the current local baseline.\n'
  printf 'Run macsync apply to review and pull the incoming baseline.\n'
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/macsync.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

POLICY="$REPO/brew/retired-casks.txt"
[[ -f "$POLICY" ]] || {
  printf 'STOP: Retirement policy is missing.\n'
  exit 1
}

# Validate every policy entry before using it as an uninstall argument.
while IFS= read -r ENTRY || [[ -n "$ENTRY" ]]; do
  case "$ENTRY" in ''|\#*) continue ;; esac
  [[ "$ENTRY" =~ ^[a-z0-9][a-z0-9@+._-]*$ ]] || {
    printf 'STOP: Invalid retired cask: %s\n' "$ENTRY"
    exit 1
  }
  printf '%s\n' "$ENTRY"
done < "$POLICY" | sort -u > "$WORK/retired"

# Reject shared retirements that are required by either machine profile.
for CHECK_PROFILE in shannon phl; do
  MAC_ENV_PROFILE="$CHECK_PROFILE" brew bundle list --cask \
    --file="$REPO/Brewfile" > "$WORK/required-$CHECK_PROFILE"
  while IFS= read -r ENTRY; do
    if grep -Fxq "$ENTRY" "$WORK/required-$CHECK_PROFILE"; then
      printf 'STOP: %s is both retired and required by %s.\n' \
        "$ENTRY" "$CHECK_PROFILE"
      exit 1
    fi
  done < "$WORK/retired"
done

brew list --cask | sort -u > "$WORK/installed"
sort -u "$WORK/required-$PROFILE" > "$WORK/required"

printf '\n=== SHARED FILES ===\n'
DRIFT=0
for item in .zshenv .zprofile .zshrc fixram.sh memory_diagnostic.sh cleanmac.sh macsync.sh; do
  case "$item" in
    .*) SOURCE="shell/$item"; LIVE="$HOME/$item" ;;
    cleanmac.sh|macsync.sh)
      SOURCE="shell/scripts/$item"
      LIVE="$HOME/.local/bin/${item%.sh}"
      ;;
    *) SOURCE="shell/scripts/$item"; LIVE="$HOME/$item" ;;
  esac
  if cmp -s "$REPO/$SOURCE" "$LIVE"; then
    printf 'IDENTICAL: %s\n' "$LIVE"
  else
    printf 'INSTALL OR UPDATE: %s\n' "$LIVE"
    DRIFT=1
  fi
done

printf '\n=== REQUIRED PACKAGES ===\n'
if ! brew bundle check --no-upgrade --verbose --file="$REPO/Brewfile"; then
  DRIFT=1
fi

printf '\n=== RETIRED CASKS STILL INSTALLED ===\n'
comm -12 "$WORK/retired" "$WORK/installed" > "$WORK/removals"
if [[ -s "$WORK/removals" ]]; then
  cat "$WORK/removals"
  DRIFT=1
else
  printf 'None.\n'
fi

printf '\n=== EXTRA CASKS — PRESERVED FOR REVIEW ===\n'
comm -23 "$WORK/installed" "$WORK/required" |
  comm -23 - "$WORK/retired"


printf '\n=== RETIRED APP STORE APPS STILL INSTALLED ===\n'
: > "$WORK/retired-mas"
if [[ -f "$REPO/brew/retired-mas.txt" ]]; then
  while IFS= read -r ENTRY || [[ -n "$ENTRY" ]]; do
    case "$ENTRY" in ''|\#*) continue ;; esac
    [[ "$ENTRY" =~ ^[0-9]+$ ]] || {
      printf 'STOP: Invalid retired App Store ID: %s\n' "$ENTRY"
      exit 1
    }
    if grep -Eq "^[[:space:]]*mas .*id:[[:space:]]*$ENTRY([,[:space:]]|$)" \
      "$REPO/brew/Brewfile.common" \
      "$REPO/brew/Brewfile.shannon" \
      "$REPO/brew/Brewfile.phl"; then
      printf 'STOP: App Store ID %s is both required and retired.\n' "$ENTRY"
      exit 1
    fi
    printf '%s\n' "$ENTRY" >> "$WORK/retired-mas"
  done < "$REPO/brew/retired-mas.txt"
fi

mas list > "$WORK/mas-installed"
awk '{print $1}' "$WORK/mas-installed" |
  sort -u > "$WORK/mas-installed-ids"
sort -u "$WORK/retired-mas" > "$WORK/mas-retired-ids"
comm -12 "$WORK/mas-retired-ids" "$WORK/mas-installed-ids" \
  > "$WORK/mas-removals"

if [[ -s "$WORK/mas-removals" ]]; then
  while IFS= read -r ENTRY; do
    awk -v id="$ENTRY" '$1 == id' "$WORK/mas-installed"
  done < "$WORK/mas-removals"
  DRIFT=1
else
  printf 'None.\n'
fi

if [[ "$ACTION" == status ]]; then
  printf '\nCoverage: declared Brewfile packages and listed shared files.\n'
  printf 'Unmanaged apps, extra formulae and NVM are not reconciled.\n'
  [[ "$AHEAD" == 0 && "$BEHIND" == 0 &&
     -z "$(git status --porcelain)" && "$DRIFT" == 0 ]]
  exit $?
fi

printf '\nApply shared files, install missing requirements without upgrades,\n'
printf 'and uninstall only the retired casks and App Store apps listed above? [y/N] '
read -r ANSWER
case "$ANSWER" in y|Y|yes|YES) ;; *) exit 1 ;; esac

for item in .zshenv .zprofile .zshrc; do
  /bin/zsh -n "$REPO/shell/$item"
done
for item in fixram.sh memory_diagnostic.sh; do
  /bin/zsh -n "$REPO/shell/scripts/$item"
done
/bin/bash -n "$REPO/shell/scripts/cleanmac.sh"
/bin/bash -n "$REPO/shell/scripts/macsync.sh"

BACKUP="$HOME/.zsh-backups/macsync-$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$BACKUP" "$HOME/.local/bin"
for item in fixram.sh memory_diagnostic.sh; do
  [[ ! -e "$HOME/$item" ]] ||
    cp -p "$HOME/$item" "$BACKUP/$item"
done
for item in cleanmac macsync; do
  [[ ! -e "$HOME/.local/bin/$item" ]] ||
    cp -p "$HOME/.local/bin/$item" "$BACKUP/$item"
done

# Delegate shell deployment to the existing guarded workflow.
/bin/zsh -lic 'shellsync pull'

for item in cleanmac macsync; do
  cp -p "$REPO/shell/scripts/$item.sh" "$HOME/.local/bin/$item"
  chmod 755 "$HOME/.local/bin/$item"
done

/bin/bash "$REPO/shell/scripts/run-with-activity.sh" "Package installation" brew bundle install --no-upgrade --verbose --file="$REPO/Brewfile"

while IFS= read -r ENTRY; do
  brew uninstall --cask "$ENTRY"
done < "$WORK/removals"

while IFS= read -r ENTRY; do
  # A cask removal may already have removed the same app bundle.
  mas list > "$WORK/mas-current"
  if awk -v id="$ENTRY" '$1 == id {found=1} END {exit !found}' \
    "$WORK/mas-current"; then
    mas uninstall "$ENTRY"
  fi
done < "$WORK/mas-removals"

brew bundle check --no-upgrade --verbose --file="$REPO/Brewfile"
printf '\nBackup: %s\n' "$BACKUP"
printf 'Apply complete. Open a new login shell after shell-file changes.\n'
printf 'Verifying final state...\n'
exec /bin/bash "$REPO/shell/scripts/macsync.sh" status
