#!/usr/bin/env bash
set -euo pipefail

# Build one separate reverse_exe-5.10.ko for each exact ARM64 5.10.x
# prepared device kernel tree.
# Usage: scripts/build-many-kernels.sh <kernel-build-tree-1> [more trees...]

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <prepared-5.10.x-kernel-build-tree> [more trees...]" >&2
  exit 2
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILED=0

for KDIR in "$@"; do
  echo
  echo "===== reverse_exe ARM64 5.10 build: $KDIR ====="
  if "$PROJECT_ROOT/scripts/build-module.sh" "$KDIR"; then
    echo "SUCCESS: $KDIR"
  else
    echo "FAILED: $KDIR" >&2
    FAILED=1
  fi
done

exit "$FAILED"
