#!/usr/bin/env bash
set -euo pipefail

# Build a distinct module for each exact prepared kernel build tree.
# The artifact basename is reverse_exe-<major>.<minor>.ko.
# Full release-specific directories prevent same-family builds overwriting.
# Usage: scripts/build-many-kernels.sh <kernel-build-tree-1> [kernel-build-tree-2 ...]

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <prepared-kernel-build-tree> [more-kernel-build-trees...]" >&2
  exit 2
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILED=0

for KDIR in "$@"; do
  echo
  echo "===== reverse_exe build: $KDIR ====="
  if "$PROJECT_ROOT/scripts/build-module.sh" "$KDIR"; then
    echo "SUCCESS: $KDIR"
  else
    echo "FAILED: $KDIR" >&2
    FAILED=1
  fi
done

exit "$FAILED"
