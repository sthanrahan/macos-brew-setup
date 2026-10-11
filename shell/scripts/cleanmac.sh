#!/bin/bash
set -eu

printf '\nMAC MAINTENANCE\n'
printf '\nFree space before cleanup:\n'
df -h "$HOME"

if command -v brew >/dev/null 2>&1; then
    printf '\nRunning Homebrew cleanup...\n'
    brew cleanup
else
    printf '\nHomebrew unavailable; skipping package cleanup.\n'
fi

printf '\nFlushing pending disk writes...\n'
sync

printf '\nFree space after cleanup:\n'
df -h "$HOME"

printf '\nDone. Use fixram for memory and disk diagnostics.\n'
