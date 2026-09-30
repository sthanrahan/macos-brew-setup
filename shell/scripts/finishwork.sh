#!/bin/zsh
set -euo pipefail

WORKDIR="$HOME/Work/Active"
STATE_FILE="$HOME/.active_work_tenant"

# 1. Determine the target tenant (Argument first, fallback to state file)
TARGET="${1:-}"
if [[ -z "$TARGET" && -f "$STATE_FILE" ]]; then
  TARGET=$(cat "$STATE_FILE")
fi

TARGET_LOWER=$(echo "$TARGET" | tr '[:upper:]' '[:lower:]')

case "$TARGET_LOWER" in
  praxis|phl)
    ONEDRIVE_DIR="$HOME/Library/CloudStorage/OneDrive-PraxisHealthLimited"
    LABEL="Praxis Health Limited"
    ;;
  kkt)
    ONEDRIVE_DIR="$HOME/Library/CloudStorage/OneDrive - KŌ Kollective Trust"
    LABEL="KŌ Kollective Trust"
    ;;
  personal)
    ONEDRIVE_DIR="$HOME/Library/CloudStorage/OneDrive - Personal"
    LABEL="Personal"
    ;;
  *)
    echo "❌ Error: Destination unknown. Please provide a parameter:"
    echo "Usage: finishwork [phl|kkt|personal]"
    exit 1
    ;;
esac

if [[ ! -d "$WORKDIR" ]]; then
  echo "❌ Error: Local staging directory '$WORKDIR' does not exist."
  exit 1
fi

if [[ ! -d "$ONEDRIVE_DIR" ]]; then
  echo "❌ Error: Cloud path missing. Ensure OneDrive app is running."
  exit 1
fi

# ⚡ THE FIX: Wake up the OneDrive File Provider daemon safely before using mkdir
echo "⏳ Waking up cloud file provider daemon for $LABEL..."
local_test_file="$ONEDRIVE_DIR/.wake_provider"
touch "$local_test_file" 2>/dev/null || true
rm -f "$local_test_file" 2>/dev/null || true

DATESTAMP=$(date +"%Y-%m-%d_%H-%M")
DEST="$ONEDRIVE_DIR/Finished Work/$DATESTAMP"

echo "📦 Syncing staging environment to $LABEL..."
mkdir -p "$DEST"
rsync -av --progress "$WORKDIR/" "$DEST/"

# Flush filesystem buffers and clean up state
sync
rm -f "$STATE_FILE"

echo "✅ Backup sequence complete. Files archived securely inside: $DEST"
open "$DEST"