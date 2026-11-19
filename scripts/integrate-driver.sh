#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <GKI-repo-root>" >&2
  exit 2
fi

REPO_ROOT="$(cd "$1" && pwd)"
KERNEL="$REPO_ROOT/common"
DRIVER_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../driver" && pwd)"
MISC="$KERNEL/drivers/misc"

if [ ! -d "$KERNEL/arch/arm64/configs" ] || [ ! -f "$MISC/Kconfig" ] || [ ! -f "$MISC/Makefile" ]; then
  echo "This does not look like an Android Common Kernel checkout: $KERNEL" >&2
  exit 1
fi

DEST="$MISC/linux_kernel_driver"
mkdir -p "$DEST"
install -m 0644 "$DRIVER_SRC/linux_kernel_driver.c" "$DEST/"
install -m 0644 "$DRIVER_SRC/Kconfig" "$DEST/"
install -m 0644 "$DRIVER_SRC/Makefile" "$DEST/"

if ! grep -Fq 'source "drivers/misc/linux_kernel_driver/Kconfig"' "$MISC/Kconfig"; then
  printf '\nsource "drivers/misc/linux_kernel_driver/Kconfig"\n' >> "$MISC/Kconfig"
fi

if ! grep -Fq 'CONFIG_LINUX_KERNEL_DRIVER' "$MISC/Makefile"; then
  printf '\nobj-$(CONFIG_LINUX_KERNEL_DRIVER) += linux_kernel_driver/\n' >> "$MISC/Makefile"
fi

DEFCONFIG="$KERNEL/arch/arm64/configs/gki_defconfig"
if [ ! -f "$DEFCONFIG" ]; then
  echo "Missing expected ARM64 GKI defconfig: $DEFCONFIG" >&2
  exit 1
fi

if ! grep -q '^CONFIG_LINUX_KERNEL_DRIVER=' "$DEFCONFIG"; then
  printf '\nCONFIG_LINUX_KERNEL_DRIVER=m\n' >> "$DEFCONFIG"
fi

echo "Integrated diagnostic module into $KERNEL"
