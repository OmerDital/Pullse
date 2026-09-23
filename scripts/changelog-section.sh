#!/bin/sh
# Print the body of one version's section of CHANGELOG.md (used as release notes).
# Exits 1 when the section is missing or empty.
set -eu
cd "$(dirname "$0")/.."
VERSION="${1:?usage: changelog-section.sh <version>}"

# Lines after "## [<version>]" up to the next "## [" heading, without leading blank
# lines; $(...) drops the trailing ones.
NOTES="$(awk -v heading="## [$VERSION]" '
    index($0, heading) == 1 { found = 1; next }
    found && /^## \[/ { exit }
    found && (seen || NF) { seen = 1; print }
' CHANGELOG.md)"

if [ -z "$NOTES" ]; then
    echo "error: CHANGELOG.md has no notes for [$VERSION]" >&2
    exit 1
fi
printf '%s\n' "$NOTES"
