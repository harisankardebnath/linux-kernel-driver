#!/usr/bin/env bash
set -euo pipefail
INPUT_ROOT="${1:-collected}"
OUTPUT_ROOT="${2:-loaders}"
mkdir -p "$OUTPUT_ROOT"
python3 - "$INPUT_ROOT" "$OUTPUT_ROOT" <<'PY'
from pathlib import Path
import base64, sys
src, dst = map(Path, sys.argv[1:])
count = 0
for ko in sorted(src.glob('**/*.ko')):
    kernel_file = ko.parent / 'kernelrelease.txt'
    if not kernel_file.is_file():
        raise SystemExit(f'Missing kernelrelease.txt beside {ko}')
    release = kernel_file.read_text().strip()
    version = ko.stem.rsplit('-', 1)[-1]
    payload = base64.b64encode(ko.read_bytes()).decode('ascii')
    name = 'vantex'
    script = """#!/system/bin/sh
# VANTEX Driver: standalone embedded module loader and manager
set -u
EXPECTED_RELEASE='"""+release.replace("'","'\\''")+"""'
MODULE_NAME='reverse_exe'
PAYLOAD_MARKER='__VANTEX_KO_PAYLOAD__'
TMPDIR_VANTEX="${TMPDIR:-/data/local/tmp}"
TMP_KO="$TMPDIR_VANTEX/vantex-$EXPECTED_RELEASE-$$.ko"
cleanup() { rm -f "$TMP_KO"; }
trap cleanup EXIT HUP INT TERM
fail() { printf 'ERROR: %s\\n' "$*" >&2; return 1; }
is_loaded() { [ -d "/sys/module/$MODULE_NAME" ] || grep -qE "^$MODULE_NAME " /proc/modules 2>/dev/null; }
root_check() { [ "$(id -u 2>/dev/null || echo 1)" = 0 ] || { fail "Root access required"; return 1; }; }
extract_payload() {
  mkdir -p "$TMPDIR_VANTEX" || return 1
  sed '1,/^__VANTEX_KO_PAYLOAD__$/d' "$0" | base64 -d > "$TMP_KO" || { fail "Embedded module extraction failed"; return 1; }
  [ -s "$TMP_KO" ] || { fail "Embedded module is empty"; return 1; }
}
load_driver() {
  root_check || return 1
  [ "$(uname -m)" = aarch64 ] || { fail "ARM64 device required"; return 1; }
  [ "$(uname -r)" = "$EXPECTED_RELEASE" ] || { fail "Kernel mismatch; built for $EXPECTED_RELEASE, running $(uname -r)"; return 1; }
  if is_loaded; then echo "Already loaded; skipping."; return 0; fi
  extract_payload || return 1
  if insmod "$TMP_KO"; then
    sleep 1
    is_loaded && { echo "VANTEX module loaded and verified."; return 0; }
    fail "insmod returned success but module is not registered."
  else
    fail "Load failed; no automatic reboot. Check dmesg for ABI/signing errors."
    dmesg 2>/dev/null | tail -n 35
    printf '\\nType REBOOT to confirm recovery reboot, or press Enter to cancel: '
    read -r confirm
    [ "$confirm" = REBOOT ] && reboot
    return 1
  fi
}
unload_driver() {
  root_check || return 1
  if ! is_loaded; then echo "Not loaded."; return 0; fi
  printf 'Type UNLOAD to unload VANTEX: '
  read -r confirm
  [ "$confirm" = UNLOAD ] || { echo "Cancelled."; return 0; }
  rmmod "$MODULE_NAME" || { fail "Unload failed; module may be busy or non-unloadable."; dmesg 2>/dev/null | tail -n 25; return 1; }
  echo "Unloaded."
}
while :; do
  clear 2>/dev/null || true
  echo '===================================='
  echo '        VANTEX DRIVER MANAGER'
  echo '===================================='
  echo "Kernel: $(uname -r)"
  echo "Built : $EXPECTED_RELEASE"
  if is_loaded; then echo 'Status: LOADED'; else echo 'Status: NOT LOADED'; fi
  echo '------------------------------------'
  echo '1) Load embedded module'
  echo '2) Check status'
  echo '3) Unload module'
  echo '4) Reload module'
  echo '5) View kernel logs'
  echo '6) Exit'
  printf 'Select: '
  read -r choice
  case "$choice" in
    1) load_driver; printf 'Press Enter...'; read -r _ ;;
    2) if is_loaded; then echo 'Loaded'; else echo 'Not loaded'; fi; printf 'Press Enter...'; read -r _ ;;
    3) unload_driver; printf 'Press Enter...'; read -r _ ;;
    4) unload_driver && load_driver; printf 'Press Enter...'; read -r _ ;;
    5) dmesg 2>/dev/null | tail -n 60; printf 'Press Enter...'; read -r _ ;;
    6) echo 'Exit. Driver state unchanged.'; exit 0 ;;
    *) echo 'Invalid option'; sleep 1 ;;
  esac
done
__VANTEX_KO_PAYLOAD__
""" + payload + "\n"
    out = dst / f'vantex-linux-{version}-arm64.sh'
    out.write_text(script)
    out.chmod(0o755)
    count += 1
if not count:
    raise SystemExit('No .ko artifacts found')
print(f'Generated {count} standalone VANTEX shell installer(s) with embedded modules in {dst}')
PY
