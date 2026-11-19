#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JOBS="${JOBS:-4}"

declare -A BRANCHES=(
  ["5.10"]="common-android13-5.10"
  ["5.15"]="common-android14-5.15"
  ["6.1"]="common-android14-6.1"
)

if ! command -v repo >/dev/null 2>&1; then
  echo "The Android repo tool is required."
  echo "Install it from https://gerrit.googlesource.com/git-repo"
  exit 1
fi

VERSIONS=("$@")
if [ "${#VERSIONS[@]}" -eq 0 ]; then
  VERSIONS=("5.10" "5.15" "6.1")
fi

for version in "${VERSIONS[@]}"; do
  branch="${BRANCHES[$version]:-}"
  if [ -z "$branch" ]; then
    echo "Unsupported version: $version" >&2
    exit 2
  fi

  dest="$ROOT/sources/$version"
  mkdir -p "$dest"
  echo "=== Fetching GKI $version ($branch) ==="
  (
    cd "$dest"
    repo init -u https://android.googlesource.com/kernel/manifest -b "$branch"
    repo sync -c --no-tags -j"$JOBS"
  )
done
