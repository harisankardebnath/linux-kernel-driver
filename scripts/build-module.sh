#!/usr/bin/env bash
set -euo pipefail

# Build reverse_exe against one exact prepared kernel build tree.
# Artifact filename is the kernel family: reverse_exe-<major>.<minor>.ko
# Exact patch/vendor release and build metadata remain isolated in OUTDIR.
# Usage: scripts/build-module.sh <prepared-kernel-build-tree> [output-root]

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "Usage: $0 <prepared-kernel-build-tree> [output-root]" >&2
  exit 2
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KDIR="$(cd "$1" && pwd)"
if [ ! -f "$KDIR/.config" ] || [ ! -f "$KDIR/Makefile" ]; then
  echo "Provide a configured/prepared kernel build tree containing .config and Makefile." >&2
  exit 1
fi

KERNELRELEASE="$(make -s -C "$KDIR" kernelrelease)"
FAMILY="$(printf '%s\n' "$KERNELRELEASE" | grep -oE '^[0-9]+\.[0-9]+' || true)"
if [ -z "$FAMILY" ]; then
  echo "Cannot parse major.minor kernel family from: $KERNELRELEASE" >&2
  exit 1
fi
grep -q '^CONFIG_ARM64=y' "$KDIR/.config" || { echo "ARM64 kernel required." >&2; exit 1; }

OUTPUT_ROOT="${2:-$PROJECT_ROOT/artifacts/per-kernel}"
OUTDIR="$OUTPUT_ROOT/$KERNELRELEASE-arm64"
mkdir -p "$OUTDIR"

make -C "$KDIR" M="$PROJECT_ROOT/driver" CONFIG_REVERSE_EXE=m modules

MODULE="$PROJECT_ROOT/driver/reverse_exe.ko"
[ -f "$MODULE" ] || { echo "Expected module not produced: $MODULE" >&2; exit 1; }

ARTIFACT="$OUTDIR/reverse_exe-$FAMILY.ko"
cp "$MODULE" "$ARTIFACT"
cp "$KDIR/.config" "$OUTDIR/kernel.config"
[ ! -f "$KDIR/Module.symvers" ] || cp "$KDIR/Module.symvers" "$OUTDIR/Module.symvers"
printf '%s\n' "$KERNELRELEASE" > "$OUTDIR/kernelrelease.txt"
printf '%s\n' "$FAMILY" > "$OUTDIR/kernel-family.txt"
if [ -d "$KDIR/include/generated" ]; then
  find "$KDIR/include/generated" -type f -print0 | sort -z | xargs -0 sha256sum > "$OUTDIR/generated-headers.sha256"
fi
sha256sum "$ARTIFACT" > "$OUTDIR/SHA256SUMS"
echo "Created: $ARTIFACT"
echo "Exact target kernel: $KERNELRELEASE"
echo "Artifact family label: $FAMILY"
echo "Each build is isolated by its exact release directory; a module still only matches its tested ABI/KMI."
