#!/bin/sh
# swift test, retried only for one known toolchain flake: with just the Command Line Tools
# the Swift Testing macro plugin sometimes fails to load ("plugin for module
# 'TestingMacros' not found") and a plain re-run passes. Real failures are not retried.
set -u
cd "$(dirname "$0")/.."

LOG="$(mktemp -t pullse-test)"
STATUS="$(mktemp -t pullse-status)"
trap 'rm -f "$LOG" "$STATUS"' EXIT
for attempt in 1 2 3; do
    # Stream the output and keep swift test's own exit status (sh has no pipefail).
    { swift test "$@" 2>&1; echo $? > "$STATUS"; } | tee "$LOG"
    [ "$(cat "$STATUS")" = 0 ] && exit 0
    grep -q "plugin for module 'TestingMacros' not found" "$LOG" || exit 1
    echo "note: TestingMacros plugin failed to load, retrying ($attempt/3)" >&2
done
exit 1
