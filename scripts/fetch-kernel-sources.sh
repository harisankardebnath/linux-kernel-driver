#!/usr/bin/env bash
set -euo pipefail

# Fetch upstream stable source trees for the requested compatibility families
# and the official Motorola MTK source branch matching Moto G64 firmware line.
# Usage: scripts/fetch-kernel-sources.sh [destination]
DEST="${1:-$(pwd)/kernel-sources}"
mkdir -p "$DEST"

STABLE_URL="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"
FAMILIES=(4.4 4.9 4.14 4.19 5.4 5.10 5.15 6.1)

clone_or_update() {
  local url="$1" branch="$2" dir="$3"
  if [ -d "$dir/.git" ]; then
    git -C "$dir" fetch --depth=1 origin "$branch"
    git -C "$dir" checkout -B "$branch" FETCH_HEAD
  else
    git clone --depth=1 --single-branch --branch "$branch" "$url" "$dir"
  fi
}

for family in "${FAMILIES[@]}"; do
  echo "===== Fetching upstream stable Linux $family.y ====="
  clone_or_update "$STABLE_URL" "linux-$family.y" "$DEST/linux-$family"
done

echo "===== Fetching Motorola MTK source for Moto G64/cancunf ====="
clone_or_update \
  "https://github.com/MotorolaMobilityLLC/kernel-mtk.git" \
  "android-15-release-v1tds35h.83-20-5-2" \
  "$DEST/motorola-kernel-mtk-v1tds35h-83-20-5-2"

echo
echo "Sources fetched under: $DEST"
echo "NOTE: upstream stable trees are generic compatibility targets, not device vendor trees."
echo "The Motorola branch is Linux 5.10.218; confirm its exact config/build metadata against your installed firmware before building/loading."
