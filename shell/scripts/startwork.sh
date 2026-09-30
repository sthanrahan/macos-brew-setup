#!/bin/zsh
set -euo pipefail

# Convert the input argument to lowercase
TARGET="${1:-}"
TARGET_LOWER=$(echo "$TARGET" | tr '[:upper:]' '[:lower:]')

case "$TARGET_LOWER" in
  praxis|phl)
    ONEDRIVE_DIR="$HOME/Library/CloudStorage/OneDrive-PraxisHealthLimited"
    LABEL="Praxis Health Limited"
    TAG="praxis"
    ;;
  kkt)
    ONEDRIVE_DIR="$HOME/Library/CloudStorage/OneDrive - KŌ Kollective Trust"
    LABEL="KŌ Kollective Trust"
    TAG="kkt"
    ;;
  personal)
    ONEDRIVE_DIR="$HOME/Library/CloudStorage/OneDrive - Personal"
    LABEL="Personal"
    TAG="personal"
    ;;
  *)
    echo "❌ Error: Please specify a valid target tenant."
    echo "Usage: startwork [phl|kkt|personal] (Caps do not matter)"
    exit 1
    ;;
esac

WORKDIR="$HOME/Work/Active"
echo "🧹 Initializing workspace for $LABEL..."

# Clean up or create the local workspace safely
if [[ -d "$WORKDIR" ]]; then
  rm -rf "$WORKDIR"
fi
mkdir -p "$WORKDIR"

# Save the active tenant selection to a state file for finishwork.sh to read later
echo "$TAG" > "$HOME/.active_work_tenant"

# Check if there is an existing cloud folder to pull latest files down from
if [[ -d "$ONEDRIVE_DIR/Finished Work" ]]; then
  LATEST_CLOUD_DIR=$(ls -td "$ONEDRIVE_DIR/Finished Work"/* 2>/dev/null | head -n 1 || true)
  if [[ -n "$LATEST_CLOUD_DIR" && -d "$LATEST_CLOUD_DIR" ]]; then
    echo "📥 Pulling latest workspace files from cloud cache..."
    rsync -av "$LATEST_CLOUD_DIR/" "$WORKDIR/"
  fi
fi

echo "🛑 Minimizing Finder file-preview overhead..."
osascript -e 'tell application "Finder" to close every window' 2>/dev/null
killall Finder 2>/dev/null

sync
echo "✅ Local staging environment ready. Open files inside: $WORKDIR"
open "$WORKDIR"