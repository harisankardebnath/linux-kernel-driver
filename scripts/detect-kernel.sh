#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <kernel-source-root>" >&2
  exit 2
fi

ROOT="$(cd "$1" && pwd)"
if [ ! -f "$ROOT/Makefile" ]; then
  echo "No kernel Makefile found at $ROOT" >&2
  exit 1
fi

VERSION="$(make -s -C "$ROOT" kernelversion 2>/dev/null || true)"
if [ -z "$VERSION" ]; then
  echo "Unable to determine kernel version from source tree" >&2
  exit 1
fi

ARCH="$(grep -E '^(CONFIG_ARM64|CONFIG_ARM)=' "$ROOT/.config" 2>/dev/null | head -n1 || true)"
printf 'Kernel source: %s\nKernel version: %s\nArchitecture config: %s\n' "$ROOT" "$VERSION" "${ARCH:-not configured}"
printf 'Target range: Linux 4.14 through latest available; exact tree/config required.\n'
