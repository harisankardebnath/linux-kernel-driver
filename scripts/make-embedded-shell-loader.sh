#!/usr/bin/env bash
set -euo pipefail
INPUT_ROOT="${1:-collected}"
OUTPUT_ROOT="${2:-loaders}"
mkdir -p "$OUTPUT_ROOT"

python3 - "$INPUT_ROOT" "$OUTPUT_ROOT" <<'PY'
from pathlib import Path
import sys

src, dst = map(Path, sys.argv[1:])
count = 0

for ko in sorted(src.glob("**/*.ko")):
    family_file = ko.parent / "kernel-family.txt"
    release_file = ko.parent / "kernelrelease.txt"
    if not family_file.is_file() or not release_file.is_file():
        raise SystemExit(f"Missing kernel metadata beside {ko}")

    family = family_file.read_text().strip()
    release = release_file.read_text().strip()
    if not family or any(ch not in "0123456789." for ch in family):
        raise SystemExit(f"Invalid family: {family!r}")

    payload = ko.read_bytes()
    if not payload.startswith(b"\x7fELF"):
        raise SystemExit(f"Not an ELF module: {ko}")

    # The marker matches the supplied single-file style. Extraction itself
    # uses a byte offset so arbitrary ELF bytes are preserved exactly.
    script = f"""#!/system/bin/sh
# VANTEX standalone diagnostic driver loader
# Embedded payload format: shell header + #离 + raw ARM64 ELF
set -u

EXPECTED_FAMILY='{family}'
EXPECTED_RELEASE='{release}'
MODULE_NAME='reverse_exe'
PAYLOAD_OFFSET=000000000000
TMPDIR_VANTEX="${TMPDIR:-/data/local/tmp}"
TMP_KO="$TMPDIR_VANTEX/vantex-$EXPECTED_FAMILY-$$.ko"
SELF_PATH="$0"

say() {{ printf '%s\\n' "$*"; }}

if [ "$(id -u 2>/dev/null)" != 0 ]; then
    say '[ERROR] Root is required. Run: su -c sh /path/to/vantex-loader.sh'
    exit 1
fi

case "$SELF_PATH" in
    /*) ;;
    *) SELF_PATH="$(pwd)/$SELF_PATH" ;;
esac
if [ ! -r "$SELF_PATH" ]; then
    say '[ERROR] Cannot read this loader file.'
    exit 1
fi

ARCH="$(uname -m 2>/dev/null)"
[ "$ARCH" = 'aarch64' ] || {{
    say "[ERROR] ARM64 required; detected: $ARCH"
    exit 1
}}

RUNNING_RELEASE="$(uname -r 2>/dev/null)"
RUNNING_FAMILY="$(printf '%s\\n' "$RUNNING_RELEASE" | awk -F. '{{print $1 "." $2}}')"
[ "$RUNNING_FAMILY" = "$EXPECTED_FAMILY" ] || {{
    say "[ERROR] Kernel family mismatch. Built for $EXPECTED_FAMILY; running $RUNNING_RELEASE"
    exit 1
}}

if [ -d "/sys/module/$MODULE_NAME" ] || grep -q "^$MODULE_NAME " /proc/modules 2>/dev/null; then
    say '[INFO] VANTEX diagnostic driver is already loaded.'
    exit 0
fi

mkdir -p "$TMPDIR_VANTEX" || {{
    say '[ERROR] Cannot create temporary directory.'
    exit 1
}}
PAYLOAD_START=$((PAYLOAD_OFFSET + 1))
tail -c "+$PAYLOAD_START" "$SELF_PATH" > "$TMP_KO" 2>/dev/null || {{
    rm -f "$TMP_KO"
    say '[ERROR] Embedded payload extraction failed.'
    exit 1
}}

MAGIC="$(od -An -N4 -tx1 "$TMP_KO" 2>/dev/null | tr -d ' \\n')"
[ "$MAGIC" = '7f454c46' ] || {{
    rm -f "$TMP_KO"
    say '[ERROR] Extracted payload is not a valid ELF file.'
    exit 1
}}

if command -v modinfo >/dev/null 2>&1; then
    MODULE_VERMAGIC="$(modinfo -F vermagic "$TMP_KO" 2>/dev/null || true)"
    case "$MODULE_VERMAGIC" in
        "$RUNNING_RELEASE "*) ;;
        *)
            say "[WARNING] Module vermagic does not exactly match the running release."
            say "          Module: ${MODULE_VERMAGIC:-unknown}"
            say "          Running: $RUNNING_RELEASE"
            say '[WARNING] Continuing only with the kernel family check; ABI compatibility is not guaranteed.'
            ;;
    esac
fi

say "[INFO] Loading VANTEX diagnostic module for kernel family $EXPECTED_FAMILY ..."
if insmod "$TMP_KO"; then
    if [ -d "/sys/module/$MODULE_NAME" ] || grep -q "^$MODULE_NAME " /proc/modules 2>/dev/null; then
        say '[SUCCESS] VANTEX diagnostic module loaded.'
        rm -f "$TMP_KO"
        exit 0
    fi
    say '[ERROR] insmod returned success, but module is not listed as loaded.'
else
    RC=$?
    say "[ERROR] insmod failed (exit $RC)."
    say '[INFO] Check kernel logs with: dmesg | tail -n 60'
fi

rm -f "$TMP_KO"
exit 1

# The shell program ends before the embedded binary.
exit 0
#离
"""
    marker = "#离\n"
    marker_pos = script.encode("utf-8").index(marker.encode("utf-8"))
    offset = marker_pos + len(marker.encode("utf-8"))
    script = script.replace("PAYLOAD_OFFSET=000000000000", f"PAYLOAD_OFFSET={offset:012d}", 1)

    out = dst / f"vantex-linux-{family}-arm64.sh"
    out.write_bytes(script.encode("utf-8") + payload)
    out.chmod(0o755)
    count += 1

if not count:
    raise SystemExit("No .ko artifacts found")
print(f"Generated {count} standalone VANTEX diagnostic shell loader(s).")
PY
