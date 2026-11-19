#!/usr/bin/env bash
set -euo pipefail
DEV="${1:-/dev/linux_kernel_driver}"

if [ ! -c "$DEV" ]; then
  echo "Device node $DEV is missing. Load the module first." >&2
  exit 1
fi

printf 'GKI diagnostic buffer test\n' > "$DEV"
printf '%s\n' "Read-back:"
cat "$DEV"
