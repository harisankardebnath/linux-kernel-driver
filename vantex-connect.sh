#!/system/bin/sh
# VANTEX safe owned-app connector check.
# Verifies only the explicit private test-buffer character device.
set -eu
NODE="${VANTEX_DEVICE:-/dev/reverse_exe}"
[ "$(uname -m)" = "aarch64" ] || { echo "VANTEX requires ARM64"; exit 1; }
[ -c "$NODE" ] || { echo "VANTEX device node not present: $NODE"; exit 1; }
echo "Found VANTEX test device: $NODE"
echo "This check does not attach to another process or access game memory."
if [ -r "$NODE" ] && [ -w "$NODE" ]; then
  echo "Device node is readable and writable by the current user."
else
  echo "Device permissions do not allow read/write for this user."
  exit 2
fi
