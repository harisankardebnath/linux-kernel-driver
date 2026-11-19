#!/usr/bin/env bash
set -euo pipefail

# Build one ARM64 Linux 5.10.x device-specific module.
# The basename is fixed at reverse_exe-5.10.ko; each exact device build
# must use its own output directory/build identity.
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
if [ "$FAMILY" != "5.10" ]; then
  echo "This project build target is ARM64 Linux 5.10.x; detected: $KERNELRELEASE" >&2
  exit 1
fi
grep -q '^CONFIG_ARM64=y' "$KDIR/.config" || { echo "ARM64 kernel required." >&2; exit 1; }

OUTPUT_ROOT="${2:-$PROJECT_ROOT/artifacts/per-kernel}"
OUTDIR="$OUTPUT_ROOT/$KERNELRELEASE-arm64"
mkdir -p "$OUTDIR"

make -C "$KDIR" M="$PROJECT_ROOT/driver" CONFIG_REVERSE_EXE=m modules

MODULE="$PROJECT_ROOT/driver/reverse_exe.ko"
[ -f "$MODULE" ] || { echo "Expected module not produced: $MODULE" >&2; exit 1; }

ARTIFACT="$OUTDIR/reverse_exe-5.10.ko"
cp "$MODULE" "$ARTIFACT"
cp "$KDIR/.config" "$OUTDIR/kernel.config"
[ ! -f "$KDIR/Module.symvers" ] || cp "$KDIR/Module.symvers" "$OUTDIR/Module.symvers"
printf '%s\n' "$KERNELRELEASE" > "$OUTDIR/kernelrelease.txt"
printf '%s\n' "5.10" > "$OUTDIR/kernel-family.txt"
if [ -d "$KDIR/include/generated" ]; then
  find "$KDIR/include/generated" -type f -print0 | sort -z | xargs -0 sha256sum > "$OUTDIR/generated-headers.sha256"
fi
sha256sum "$ARTIFACT" > "$OUTDIR/SHA256SUMS"
echo "Created: $ARTIFACT"
echo "Exact target kernel: $KERNELRELEASE"
echo "This artifact is built for this exact device kernel tree; the filename does not imply cross-device ABI compatibility."
