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
    kr = ko.parent / 'kernelrelease.txt'
    if not kr.is_file():
        raise SystemExit(f'Missing kernelrelease.txt beside {ko}')
    release = kr.read_text().strip()
    version = ko.stem.rsplit('-', 1)[-1]
    payload = base64.b64encode(ko.read_bytes()).decode('ascii')
    script = '''#!/system/bin/sh
set -eu
EXPECTED_RELEASE=''' + "'" + release.replace("'", "'\\''") + "'" + '''
MODULE_NAME=reverse_exe
fail() { echo "ERROR: $*" >&2; exit 1; }
[ "$(id -u)" = 0 ] || fail "Run as root."
[ "$(uname -m)" = aarch64 ] || fail "ARM64 device required."
[ "$(uname -r)" = "$EXPECTED_RELEASE" ] || fail "Kernel mismatch: expected $EXPECTED_RELEASE, found $(uname -r)."
if [ -d "/sys/module/$MODULE_NAME" ]; then echo "$MODULE_NAME already loaded."; exit 0; fi
command -v base64 >/dev/null 2>&1 || fail "base64 command required."
TMP="${TMPDIR:-/data/local/tmp}/$MODULE_NAME-$$.ko"
trap 'rm -f "$TMP"' EXIT HUP INT TERM
sed '1,/^__KO_PAYLOAD_BELOW__$/d' "$0" | base64 -d > "$TMP" || fail "Payload extraction failed."
[ -s "$TMP" ] || fail "Empty module payload."
insmod "$TMP" || fail "insmod failed; inspect dmesg for ABI/symbol/signing errors."
[ -d "/sys/module/$MODULE_NAME" ] || fail "Module load verification failed."
echo "Diagnostic module loaded and verified."
exit 0
__KO_PAYLOAD_BELOW__
''' + payload + '\n'
    out = dst / f'ko-loader-linux-{version}.sh'
    out.write_text(script)
    out.chmod(0o755)
    count += 1
if not count:
    raise SystemExit('No .ko artifacts found')
print(f'Generated {count} embedded diagnostic loader(s) in {dst}')
PY