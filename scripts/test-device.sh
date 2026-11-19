#!/usr/bin/env bash
set -euo pipefail
DEV="${1:-/dev/reverse_exe}"

if [ ! -c "$DEV" ]; then
  echo "Device node $DEV is missing. Load the matching reverse_exe module first." >&2
  exit 1
fi

printf 'reverse_exe private buffer test\n' > "$DEV"
printf '%s\n' "Read-back:"
cat "$DEV"
