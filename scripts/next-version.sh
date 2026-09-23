#!/bin/sh
# Print the version the notes under CHANGELOG.md's [Unreleased] call for, or exit 1 when
# there are none (nothing to release). The bump comes from the Keep a Changelog headings:
#   ### Breaking                                → major (minor while below 1.0.0)
#   ### Added / Changed / Deprecated / Removed  → minor
#   anything else (### Fixed, ### Security, …)  → patch
# 1.0.0 is therefore never picked automatically; release it on purpose with an explicit
# version (the Release workflow's manual run, or scripts/release.sh 1.0.0).
set -eu
cd "$(dirname "$0")/.."

NOTES="$(scripts/changelog-section.sh Unreleased 2>/dev/null)" || exit 1
CURRENT="$(tr -d '[:space:]' < VERSION)"

printf '%s\n' "$NOTES" | awk -v current="$CURRENT" '
    /^### +Breaking/ { level = 3 }
    /^### +(Added|Changed|Deprecated|Removed)/ { if (level < 2) level = 2 }
    END {
        # After a prerelease the next release is the version it was a preview of.
        split(current, core, "-")
        if (core[1] != current) { print core[1]; exit }
        split(core[1], v, ".")
        major = v[1] + 0; minor = v[2] + 0; patch = v[3] + 0
        if (level == 3 && major == 0) level = 2
        if (level == 3)      { major++; minor = 0; patch = 0 }
        else if (level == 2) { minor++; patch = 0 }
        else                 { patch++ }
        print major "." minor "." patch
    }'
