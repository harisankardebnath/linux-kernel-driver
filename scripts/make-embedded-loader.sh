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
    family_file = ko.parent / 'kernel-family.txt'
    if not kernel_file.is_file() or not family_file.is_file():
        raise SystemExit(f'Missing kernelrelease.txt or kernel-family.txt beside {ko}')
    release = kernel_file.read_text().strip()
    family = family_file.read_text().strip()
    if not family or any(c not in '0123456789.' for c in family):
        raise SystemExit(f'Invalid kernel family metadata: {family!r}')
    payload = base64.b64encode(ko.read_bytes()).decode('ascii')
    script = """#!/system/bin/sh
# VANTEX standalone ARM64 module manager
set -u
EXPECTED_RELEASE='"""+release.replace("'","'\\''")+"""'
KERNEL_FAMILY='"""+family+"""'
MODULE_NAME='reverse_exe'
TMPDIR_VANTEX="${TMPDIR:-/data/local/tmp}"
TMP_KO="$TMPDIR_VANTEX/vantex-$KERNEL_FAMILY-$$.ko"
RED='\\033[31m'; GREEN='\\033[32m'; YELLOW='\\033[33m'
CYAN='\\033[36m'; RESET='\\033[0m'; BOLD='\\033[1m'
cleanup() { rm -f "$TMP_KO"; }
restore_terminal() { [ -n "${OLD_STTY:-}" ] && stty "$OLD_STTY" 2>/dev/null; }
trap cleanup EXIT
trap 'restore_terminal; exit 130' INT TERM HUP
say_error() { printf "${RED}[ERROR] %s${RESET}\\n" "$*" >&2; }
say_ok() { printf "${GREEN}[OK] %s${RESET}\\n" "$*"; }
say_warn() { printf "${YELLOW}[WARNING] %s${RESET}\\n" "$*"; }
is_loaded() { [ -d "/sys/module/$MODULE_NAME" ] || grep -qE "^$MODULE_NAME " /proc/modules 2>/dev/null; }
root_check() {
  if [ "$(id -u 2>/dev/null || echo 1)" = 0 ]; then return 0; fi
  say_error "Root access required."
  say_warn "Open a root shell first, then run this script again:"
  printf "  su\\n  sh '%s'\\n" "$0"
  return 1
}
extract_payload() {
  mkdir -p "$TMPDIR_VANTEX" || return 1
  sed '1,/^__VANTEX_KO_PAYLOAD__$/d' "$0" | base64 -d > "$TMP_KO" || { say_error "Embedded module extraction failed"; return 1; }
  [ -s "$TMP_KO" ] || { say_error "Embedded module is empty"; return 1; }
}
load_driver() {
  root_check || return 1
  [ "$(uname -m)" = aarch64 ] || { say_error "ARM64 device required"; return 1; }
  [ "$(uname -r)" = "$EXPECTED_RELEASE" ] || { say_error "Kernel mismatch: built for $EXPECTED_RELEASE, running $(uname -r)"; return 1; }
  if is_loaded; then say_ok "Already loaded; skipping."; return 0; fi
  extract_payload || return 1
  if insmod "$TMP_KO"; then
    sleep 1
    is_loaded && { say_ok "VANTEX module loaded."; return 0; }
    say_error "insmod succeeded but module is not registered."
  else
    say_error "Module load failed. Check kernel logs."
    dmesg 2>/dev/null | tail -n 35
  fi
  return 1
}
unload_driver() {
  root_check || return 1
  if ! is_loaded; then say_warn "Module is not loaded."; return 0; fi
  say_warn "Unloading the VANTEX module."
  rmmod "$MODULE_NAME" || { say_error "Unload failed; module may be busy."; dmesg 2>/dev/null | tail -n 25; return 1; }
  say_ok "Module unloaded."
}
pause_screen() {
  printf '\\n\\033[33mPress ENTER to continue...\\033[0m'
  IFS= read -r _ || :
  MENU_DRAWN=0
}
draw_menu() {
  if [ "${MENU_DRAWN:-0}" -eq 0 ]; then
    printf '\\033[2J\\033[H'
    printf "${CYAN}${BOLD}╔══════════════════════════════════════╗\\n"
    printf "║             V A N T E X              ║\\n"
    printf "║          KERNEL MODULE PANEL         ║\\n"
    printf "╚══════════════════════════════════════╝${RESET}\\n"
    printf "${CYAN}  Kernel  ${RESET}%s\\n" "$(uname -r | cut -d- -f1)"
    if is_loaded; then printf "  Status  ${GREEN}${BOLD}● LOADED${RESET}\\n"; else printf "  Status  ${RED}${BOLD}● NOT LOADED${RESET}\\n"; fi
    printf "${CYAN}  ────────────────────────────────────${RESET}\\n"
    printf "  MODULE CONTROL\\n"
    MENU_DRAWN=1
  else
    printf '\\033[8;1H'
  fi
  items="Load embedded module|Check status|Unload module|Reload module|View kernel logs|Exit"
  n=1
  oldifs="$IFS"; IFS='|'
  for item in $items; do
    if [ "$n" -eq "$SELECTED" ]; then
      printf "\\033[%d;1H\\033[2K  ${GREEN}${BOLD}❯  %s  %s${RESET}\\n" "$((7+n))" "$n" "$item"
    else
      printf "\\033[%d;1H\\033[2K     %s  %s\\n" "$((7+n))" "$n" "$item"
    fi
    n=$((n + 1))
  done
  IFS="$oldifs"
  printf "\\033[15;1H\\033[2K${YELLOW}  ↑ ↓ / ← →  Navigate     ENTER  Select     Q  Quit${RESET}\\n"
}
read_choice() {
  OLD_STTY=$(stty -g 2>/dev/null) || return 1
  # VTIME lets one read collect a complete ESC [ A/B/C/D sequence without
  # blocking forever when the key was an ordinary character.
  stty -echo -icanon min 0 time 1 2>/dev/null || { restore_terminal; OLD_STTY=''; return 1; }
  keyseq=$(dd if=/dev/tty bs=16 count=1 2>/dev/null)
  restore_terminal
  OLD_STTY=''
  case "$keyseq" in
    "$(printf '\\033[A')"|"$(printf '\\033[D')") SELECTED=$((SELECTED - 1));;
    "$(printf '\\033[B')"|"$(printf '\\033[C')") SELECTED=$((SELECTED + 1));;
    "$(printf '\\r')"|"$(printf '\\n')") return 0;;
    q|Q) SELECTED=6; return 0;;
  esac
  [ "$SELECTED" -lt 1 ] && SELECTED=6
  [ "$SELECTED" -gt 6 ] && SELECTED=1
  return 1
}
SELECTED=1
while :; do
  draw_menu
  read_choice
  rc=$?
  [ "$rc" -eq 0 ] || continue
  case "$SELECTED" in
    1) load_driver; pause_screen ;;
    2) if is_loaded; then say_ok "Module is loaded."; else say_warn "Module is not loaded."; fi; pause_screen ;;
    3) unload_driver; pause_screen ;;
    4) if unload_driver; then load_driver; fi; pause_screen ;;
    5) printf '\\033[2J\\033[H'; dmesg 2>/dev/null | tail -n 60; pause_screen ;;
    6) printf "Exit. Module state unchanged.\\n"; exit 0 ;;
  esac
done
__VANTEX_KO_PAYLOAD__
""" + payload + "\n"
    out = dst / f'vantex-linux-{family}-arm64.sh'
    out.write_text(script)
    out.chmod(0o755)
    count += 1
if not count:
    raise SystemExit('No .ko artifacts found')
print(f'Generated {count} standalone VANTEX shell bundle(s) with embedded modules in {dst}')
PY
