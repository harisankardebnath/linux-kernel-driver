#!/system/bin/sh
# reverse_exe.sh — diagnostic-only package inspector
# This script DOES NOT insert, load, or execute a kernel module.

set -u

GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

say() { printf '%b%s%b\n' "$1" "$2" "$RESET"; }

say "$GREEN" "[reverse_exe] Diagnostic inspector"

if [ "$(id -u 2>/dev/null)" != "0" ]; then
    say "$YELLOW" "[!] Root is not required for inspection; continuing."
fi

ARCH="$(uname -m 2>/dev/null || echo unknown)"
KREL="$(uname -r 2>/dev/null || echo unknown)"

printf 'Device architecture : %s\n' "$ARCH"
printf 'Running kernel      : %s\n' "$KREL"

case "$ARCH" in
    aarch64|arm64) say "$GREEN" "[OK] ARM64 architecture detected." ;;
    *) say "$YELLOW" "[!] This package was built for ARM64; current architecture differs." ;;
esac

case "$KREL" in
    5.10.*) say "$GREEN" "[OK] Kernel release is in the 5.10 family." ;;
    *) say "$YELLOW" "[!] Kernel release is not 5.10.x; compatibility is not established." ;;
esac

if [ "$#" -lt 1 ]; then
    echo
    echo "Usage: sh reverse_exe.sh /path/to/reverse_exe-linux-5.10-arm64.zip"
    echo "Or:    sh reverse_exe.sh /path/to/reverse_exe-5.10.ko"
    exit 2
fi

INPUT="$1"
if [ ! -f "$INPUT" ]; then
    say "$RED" "[ERROR] Input file not found."
    exit 1
fi

case "$INPUT" in
    *.zip)
        if ! command -v unzip >/dev/null 2>&1; then
            say "$RED" "[ERROR] unzip is required to inspect this archive."
            exit 1
        fi
        echo
        echo "[Archive metadata]"
        unzip -Z1 "$INPUT" 2>/dev/null
        echo
        echo "[Recorded kernel release]"
        unzip -p "$INPUT" '*/kernelrelease.txt' 2>/dev/null || unzip -p "$INPUT" 'kernelrelease.txt' 2>/dev/null
        echo
        echo "[Recorded module metadata]"
        unzip -p "$INPUT" '*/modinfo.txt' 2>/dev/null || unzip -p "$INPUT" 'modinfo.txt' 2>/dev/null
        echo
        echo "[Integrity manifest]"
        unzip -p "$INPUT" '*/SHA256SUMS' 2>/dev/null || unzip -p "$INPUT" 'SHA256SUMS' 2>/dev/null
        ;;
    *.ko)
        echo
        echo "[Module file]"
        ls -l "$INPUT"
        if command -v sha256sum >/dev/null 2>&1; then
            sha256sum "$INPUT"
        fi
        if command -v modinfo >/dev/null 2>&1; then
            modinfo "$INPUT"
        else
            say "$YELLOW" "[!] modinfo is unavailable; metadata display skipped."
        fi
        ;;
    *)
        say "$RED" "[ERROR] Supply a .zip archive or .ko file."
        exit 2
        ;;
esac

echo
say "$YELLOW" "[NOTICE] Inspection only: no module was loaded or modified."
exit 0
