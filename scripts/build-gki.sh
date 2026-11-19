#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <5.10|5.15|6.1>" >&2
  exit 2
fi

VERSION="$1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/sources/$VERSION"

case "$VERSION" in
  5.10) BRANCH="common-android13-5.10" ;;
  5.15) BRANCH="common-android14-5.15" ;;
  6.1)  BRANCH="common-android14-6.1" ;;
  *) echo "Unsupported version: $VERSION" >&2; exit 2 ;;
esac

if [ ! -d "$SRC/.repo" ] || [ ! -d "$SRC/common" ]; then
  echo "Missing source checkout. Run scripts/fetch-gki.sh $VERSION first." >&2
  exit 1
fi

echo "Expected manifest branch: $BRANCH"
"$ROOT/scripts/integrate-driver.sh" "$SRC"

DIST="$ROOT/artifacts/$VERSION"
mkdir -p "$DIST"
cd "$SRC"

set -o pipefail
tools/bazel run //common:kernel_aarch64_dist -- --destdir="$DIST" 2>&1 \
  | tee "$ROOT/artifacts/build-$VERSION.log"

find "$DIST" -type f -name '*.ko' -print
echo "Artifacts: $DIST"
