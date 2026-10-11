#!/bin/bash
set -u

if (( $# < 2 )); then
  printf 'Usage: run-with-activity.sh LABEL COMMAND [ARGUMENTS...]\n' >&2
  exit 2
fi
label=$1
shift
interval=${MACSYNC_ACTIVITY_INTERVAL:-10}
if [[ ! "$interval" =~ ^[1-9][0-9]*$ ]]; then
  printf 'Invalid activity interval.\n' >&2
  exit 2
fi
SECONDS=0

heartbeat() {
  local sleeper=''
  trap 'if [[ -n "$sleeper" ]]; then kill "$sleeper" 2>/dev/null || :; wait "$sleeper" 2>/dev/null || :; fi; exit 0' TERM INT
  while :; do
    sleep "$interval" &
    sleeper=$!
    wait "$sleeper" || return
    sleeper=''
    printf '\n[Activity] %s still running — elapsed %02d:%02d:%02d\n' \
      "$label" "$((SECONDS / 3600))" \
      "$(((SECONDS % 3600) / 60))" "$((SECONDS % 60))"
  done
}

heartbeat &
timer=$!
cleanup() {
  kill "$timer" 2>/dev/null || :
  wait "$timer" 2>/dev/null || :
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

printf '\n[Started] %s\n' "$label"
if "$@"; then
  result=0
else
  result=$?
fi
cleanup
trap - EXIT INT TERM

if (( result == 0 )); then
  outcome=SUCCESS
else
  outcome=FAILED
fi
printf '\n[%s] %s — elapsed %02d:%02d:%02d — exit code %d\n' \
  "$outcome" "$label" "$((SECONDS / 3600))" \
  "$(((SECONDS % 3600) / 60))" "$((SECONDS % 60))" "$result"
exit "$result"
