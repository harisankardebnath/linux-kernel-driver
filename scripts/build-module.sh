#!/usr/bin/env bash
set -euo pipefail

# Build a distinct reverse_exe .ko for one exact prepared kernel build tree.
# Usage: scripts/build-module.sh <prepared-kernel-build-tree> [output-directory]

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "Usage: $0 <prepared-kernel-build-tree> [output-directory]" >&2
  exit 2
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KDIR="$(cd "$1" && pwd)"
if [ ! -f "$KDIR/.config" ] || [ ! -f "$KDIR/Makefile" ]; then
  echo "Provide a configured/prepared kernel build tree containing .config and Makefile." >&2
  exit 1
fi
KERNELRELEASE="$(make -s -C "$KDIR" kernelrelease)"
grep -q '^CONFIG_ARM64=y' "$KDIR/.config" || { echo "ARM64 kernel required." >&2; exit 1; }

OUTDIR="${2:-$PROJECT_ROOT/artifacts/per-kernel/$KERNELRELEASE-arm64}"
mkdir -p "$OUTDIR"
make -C "$KDIR" M="$PROJECT_ROOT/driver" modules

MODULE="$PROJECT_ROOT/driver/reverse_exe.ko"
[ -f "$MODULE" ] || { echo "Expected module not produced: $MODULE" >&2; exit 1; }

ARTIFACT="$OUTDIR/reverse_exe-$KERNELRELEASE-arm64.ko"
cp "$MODULE" "$ARTIFACT"
cp "$KDIR/.config" "$OUTDIR/kernel.config"
[ ! -f "$KDIR/Module.symvers" ] || cp "$KDIR/Module.symvers" "$OUTDIR/Module.symvers"
printf '%s\n' "$KERNELRELEASE" > "$OUTDIR/kernelrelease.txt"
sha256sum "$ARTIFACT" > "$OUTDIR/SHA256SUMS"
echo "Created: $ARTIFACT"
echo "This module is only for the exact kernel build used above."
