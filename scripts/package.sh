#!/bin/sh
# Zip build/Pullse.app for download and write its SHA-256 next to it:
#   build/Pullse-<version><suffix>.zip and .zip.sha256
# The updater looks for exactly these names on a release, so keep them in sync with
# UpdateChecker in Sources/PullseCore/Updates.swift.
set -eu
cd "$(dirname "$0")/.."

SUFFIX="${1:-}"
VERSION="$(tr -d '[:space:]' < VERSION)"
NAME="Pullse-$VERSION$SUFFIX.zip"

[ -d build/Pullse.app ] || { echo "error: build/Pullse.app missing, run make build" >&2; exit 1; }
rm -f "build/$NAME" "build/$NAME.sha256"
# ditto keeps the bundle's symlinks, extended attributes and code signature intact.
ditto -c -k --sequesterRsrc --keepParent build/Pullse.app "build/$NAME"
(cd build && shasum -a 256 "$NAME" > "$NAME.sha256")
echo "build/$NAME"
