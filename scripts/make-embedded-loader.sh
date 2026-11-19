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
for ko in sorted(src.glob('**/*.ko')):
    kernel_file = ko.parent / 'kernelrelease.txt'
    family_file = ko.parent / 'kernel-family.txt'
    if not kernel_file.is_file() or not family_file.is_file():
        raise SystemExit(f'Missing kernelrelease.txt or kernel-family.txt beside {ko}')
    release = kernel_file.read_text().strip()
    family = family_file.read_text().strip()
    if not family or any(c not in '0123456789.' for c in family):
        raise SystemExit(f'Invalid kernel family metadata: {family!r}')
    payload = ko.read_bytes()
    script = """#!/system/bin/sh
# VANTEX standalone ARM64 module manager
set -u
EXPECTED_RELEASE='"""+release.replace("'","'\\''")+"""'
KERNEL_FAMILY='"""+family+"""'
MODULE_NAME='reverse_exe'
PAYLOAD_OFFSET=000000000000
TMPDIR_VANTEX="${TMPDIR:-/data/local/tmp}"
TMP_KO="$TMPDIR_VANTEX/vantex-$KERNEL_FAMILY-$$.ko"
ESC=$(printf '\\033')
RED="${ESC}[31m"; GREEN="${ESC}[32m"; YELLOW="${ESC}[33m"
CYAN="${ESC}[36m"; WHITE="${ESC}[97m"; DIM="${ESC}[90m"
RESET="${ESC}[0m"; BOLD="${ESC}[1m"
SELECTED=1
OLD_STTY=''
cleanup() { [ -n "$OLD_STTY" ] && stty "$OLD_STTY" 2>/dev/null; rm -f "$TMP_KO"; printf '%b' "${RESET}${ESC}[?25h"; }
trap cleanup EXIT
trap 'exit 130' INT TERM HUP
is_loaded() { [ -d "/sys/module/$MODULE_NAME" ] || grep -qE "^$MODULE_NAME " /proc/modules 2>/dev/null; }
extract_payload() {
  mkdir -p "$TMPDIR_VANTEX" || return 1
  dd if="$0" of="$TMP_KO" bs=1 skip="$PAYLOAD_OFFSET" 2>/dev/null || return 1
  [ -s "$TMP_KO" ]
}
do_load() {
  [ "$(id -u 2>/dev/null)" = 0 ] || { SHOW_MSG="Root required — launch with su"; MSG_COLOR=$RED; return 1; }
  [ "$(uname -m)" = aarch64 ] || { SHOW_MSG="ARM64 device required"; MSG_COLOR=$RED; return 1; }
  [ "$(uname -r)" = "$EXPECTED_RELEASE" ] || { SHOW_MSG="Kernel mismatch — wrong bundle"; MSG_COLOR=$RED; return 1; }
  if is_loaded; then SHOW_MSG="Already loaded"; MSG_COLOR=$GREEN; return 0; fi
  extract_payload || { SHOW_MSG="Embedded module extraction failed"; MSG_COLOR=$RED; return 1; }
  if insmod "$TMP_KO" && is_loaded; then SHOW_MSG="VANTEX module loaded"; MSG_COLOR=$GREEN; return 0; fi
  SHOW_MSG="Load failed — check kernel logs"; MSG_COLOR=$RED
  return 1
}
do_unload() {
  [ "$(id -u 2>/dev/null)" = 0 ] || { SHOW_MSG="Root required — launch with su"; MSG_COLOR=$RED; return 1; }
  if ! is_loaded; then SHOW_MSG="Module is not loaded"; MSG_COLOR=$YELLOW; return 0; fi
  if rmmod "$MODULE_NAME"; then SHOW_MSG="Module unloaded"; MSG_COLOR=$GREEN; return 0; fi
  SHOW_MSG="Unload failed — module may be busy"; MSG_COLOR=$RED
  return 1
}
term_size() {
  set -- $(stty size 2>/dev/null)
  ROWS=${1:-24}; COLS=${2:-80}
  case "$ROWS:$COLS" in *[!0-9:]*|:*) ROWS=24; COLS=80;; esac
}
center() {
  row=$1; raw=$2
  plain=$(printf '%s' "$raw" | sed "s/${ESC}\\[[0-9;]*m//g")
  # Count UTF-8 characters, not bytes: box-drawing glyphs are multibyte.
  width=$(printf '%s' "$plain" | wc -m | tr -d ' ')
  case "$width" in ''|*[!0-9]*) width=${#plain};; esac
  col=$(( (COLS - width) / 2 + 1 ))
  [ "$col" -lt 1 ] && col=1
  printf '%b' "${ESC}[${row};${col}H${raw}"
}
draw_menu() {
  term_size
  printf '%b' "${ESC}[2J${ESC}[H${ESC}[?25l"
  # Fixed top placement; all content is centred independently.
  top=2
  STATUS_ROW=$((top+6)); MENU_ROW=$((top+9)); FOOT_ROW=$((top+17))
  center "$top" "${CYAN}══════════════════════════════════════════════════${RESET}"
  center "$((top+1))" "${CYAN}${BOLD}V A N T E X${RESET}"
  center "$((top+2))" "${CYAN}${BOLD}KERNEL MODULE PANEL${RESET}"
  center "$((top+3))" "${CYAN}══════════════════════════════════════════════════${RESET}"
  center "$((top+5))" "${CYAN}Kernel${RESET}  $(uname -r | cut -d- -f1)"
  draw_status
  center "$((top+7))" "${CYAN}----------------------------------------${RESET}"
  center "$((top+8))" "${DIM}MODULE CONTROL${RESET}"
  draw_items
  draw_message
}
draw_status() {
  if is_loaded; then center "$STATUS_ROW" "${WHITE}Status  ${GREEN}${BOLD}● LOADED${RESET}"
  else center "$STATUS_ROW" "${WHITE}Status  ${RED}${BOLD}● NOT LOADED${RESET}"; fi
}
draw_items() {
  names="Load module|Check status|Unload module|Reload module|View kernel logs|Exit"
  n=1; oldifs="$IFS"; IFS='|'
  for name in $names; do
    row=$((MENU_ROW+n-1))
    if [ "$n" -eq "$SELECTED" ]; then center "$row" "${GREEN}${BOLD}>  $name${RESET}"
    else center "$row" "${WHITE}   $name${RESET}"; fi
    n=$((n+1))
  done
  IFS="$oldifs"
}
draw_message() {
  printf '%b' "${ESC}[${FOOT_ROW};1H${ESC}[2K"
  if [ -n "${SHOW_MSG:-}" ]; then center "$FOOT_ROW" "${MSG_COLOR:-$YELLOW}$SHOW_MSG${RESET}"; fi
}
refresh_ui() {
  term_size
  draw_items
  draw_status
  draw_message
}
# Read one byte at a time in raw mode so ANSI arrow keys are never echoed.
read_key() {
  OLD_STTY=$(stty -g < /dev/tty 2>/dev/null) || return 1
  stty raw -echo < /dev/tty 2>/dev/null || { OLD_STTY=''; return 1; }
  key=$(dd if=/dev/tty bs=1 count=1 2>/dev/null)
  if [ "$key" = "$(printf '\\033')" ]; then
    seq=$(dd if=/dev/tty bs=1 count=2 2>/dev/null)
    case "$seq" in
      '[A'|'[D') SELECTED=$((SELECTED-1));;
      '[B'|'[C') SELECTED=$((SELECTED+1));;
    esac
  elif [ "$key" = "$(printf '\\r')" ] || [ "$key" = "$(printf '\\n')" ]; then
    stty "$OLD_STTY" < /dev/tty 2>/dev/null
    OLD_STTY=''
    return 0
  elif [ "$key" = q ] || [ "$key" = Q ]; then
    SELECTED=6
    stty "$OLD_STTY" < /dev/tty 2>/dev/null
    OLD_STTY=''
    return 0
  fi
  stty "$OLD_STTY" < /dev/tty 2>/dev/null
  OLD_STTY=''
  [ "$SELECTED" -lt 1 ] && SELECTED=6
  [ "$SELECTED" -gt 6 ] && SELECTED=1
  return 1
}
[ -t 0 ] && [ -r /dev/tty ] || { echo "VANTEX requires an interactive terminal."; exit 1; }
SHOW_MSG=''
draw_menu
while :; do
  read_key
  key_rc=$?
  if [ "$key_rc" -ne 0 ]; then refresh_ui; continue; fi
  SHOW_MSG=''
  case "$SELECTED" in
    1) do_load;;
    2) if is_loaded; then SHOW_MSG="Module is loaded"; MSG_COLOR=$GREEN; else SHOW_MSG="Module is not loaded"; MSG_COLOR=$YELLOW; fi;;
    3) do_unload;;
    4) do_unload && do_load;;
    5) SHOW_MSG="Kernel log view is not available in compact menu"; MSG_COLOR=$YELLOW;;
    6) exit 0;;
  esac
  refresh_ui
  sleep 1.5
  SHOW_MSG=''
  refresh_ui
done
exec /system/bin/true
"""
    marker = "PAYLOAD_OFFSET=000000000000"
    offset = len(script.encode("utf-8"))
    script = script.replace(marker, f"PAYLOAD_OFFSET={offset:012d}", 1)
    out = dst / f'vantex-linux-{family}-arm64.sh'
    out.write_bytes(script.encode("utf-8") + payload)
    out.chmod(0o755)
    count += 1
if not count:
    raise SystemExit('No .ko artifacts found')
print(f'Generated {count} standalone VANTEX shell bundle(s) with embedded modules in {dst}')
PY
