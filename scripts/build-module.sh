#!/usr/bin/env bash
set -euo pipefail

# Build one separate module for one exact configured kernel build tree.
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
if ! grep -q '^CONFIG_ARM64=y' "$KDIR/.config"; then
  echo "This project currently targets ARM64: CONFIG_ARM64=y is required." >&2
  exit 1
fi

OUTDIR="${2:-$PROJECT_ROOT/artifacts/per-kernel/$KERNELRELEASE-arm64}"
mkdir -p "$OUTDIR"

echo "Building for exact kernel release: $KERNELRELEASE"
echo "Kernel build tree: $KDIR"

make -C "$KDIR" M="$PROJECT_ROOT/driver" modules

MODULE="$PROJECT_ROOT/driver/linux_kernel_driver.ko"
if [ ! -f "$MODULE" ]; then
  echo "Expected module was not produced: $MODULE" >&2
  exit 1
fi

cp "$MODULE" "$OUTDIR/linux_kernel_driver-$KERNELRELEASE-arm64.ko"
cp "$KDIR/.config" "$OUTDIR/kernel.config"
if [ -f "$KDIR/Module.symvers" ]; then
  cp "$KDIR/Module.symvers" "$OUTDIR/Module.symvers"
fi
printf '%s\n' "$KERNELRELEASE" > "$OUTDIR/kernelrelease.txt"
sha256sum "$OUTDIR/linux_kernel_driver-$KERNELRELEASE-arm64.ko" > "$OUTDIR/SHA256SUMS"

echo "Created distinct artifact: $OUTDIR/linux_kernel_driver-$KERNELRELEASE-arm64.ko"
echo "Use this module only with the exact kernel build used above."
