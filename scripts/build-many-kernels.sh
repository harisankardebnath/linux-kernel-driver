#!/usr/bin/env bash
set -euo pipefail

# Build a separate reverse_exe module for each supplied prepared kernel tree.
# Each artifact is named reverse_exe-<major>.<minor>.<patch>.ko and stored
# in a directory keyed by the full exact kernel release.
# Usage: scripts/build-many-kernels.sh <kernel-build-tree-1> [kernel-build-tree-2 ...]

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <prepared-kernel-build-tree> [more-kernel-build-trees...]" >&2
  exit 2
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILED=0

for KDIR in "$@"; do
  echo
  echo "===== Separate reverse_exe build: $KDIR ====="
  if "$PROJECT_ROOT/scripts/build-module.sh" "$KDIR"; then
    echo "SUCCESS: $KDIR"
  else
    echo "FAILED: $KDIR" >&2
    FAILED=1
  fi
done

exit "$FAILED"
