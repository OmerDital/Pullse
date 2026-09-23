#!/bin/sh
# Cut a release locally: scripts/release.sh 0.2.0  (or: make release VERSION=0.2.0)
#
# Moves CHANGELOG.md's [Unreleased] notes into a dated [0.2.0] section, writes VERSION,
# commits "Release 0.2.0" and tags v0.2.0. Nothing is pushed: pushing the tag is what
# makes GitHub build and publish the release, so that step stays deliberate.
set -eu
cd "$(dirname "$0")/.."

NEW="${1:?usage: scripts/release.sh <x.y.z>}"
NEW="${NEW#v}"
CURRENT="$(tr -d '[:space:]' < VERSION)"

fail() { echo "error: $*" >&2; exit 1; }

echo "$NEW" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$' \
    || fail "$NEW is not a version like 1.2.3 or 1.2.3-beta.1"

# Succeeds when $1 is a higher SemVer than $2. A prerelease sorts below its release;
# two prereleases of the same version compare as text, which is enough for beta.1 < beta.2.
newer() {
    awk -v a="$1" -v b="$2" 'BEGIN {
        split(a, pa, "-"); split(b, pb, "-")
        split(pa[1], x, "."); split(pb[1], y, ".")
        for (i = 1; i <= 3; i++) {
            if (x[i] + 0 > y[i] + 0) exit 0
            if (x[i] + 0 < y[i] + 0) exit 1
        }
        ra = substr(a, length(pa[1]) + 2); rb = substr(b, length(pb[1]) + 2)
        if (ra == rb) exit 1
        if (ra == "") exit 0
        if (rb == "") exit 1
        exit !(ra > rb)
    }'
}
newer "$NEW" "$CURRENT" || fail "$NEW is not newer than the current version $CURRENT"

[ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || fail "releases are cut from main"
[ -z "$(git status --porcelain)" ] || fail "the working tree has uncommitted changes"
git rev-parse -q --verify "refs/tags/v$NEW" >/dev/null && fail "tag v$NEW already exists"
scripts/changelog-section.sh Unreleased >/dev/null 2>&1 \
    || fail "add notes under [Unreleased] in CHANGELOG.md first"

TODAY="$(date +%Y-%m-%d)"
awk -v version="$NEW" -v today="$TODAY" '
    !done && $0 == "## [Unreleased]" {
        print; print ""; print "## [" version "] - " today; done = 1; next
    }
    { print }
' CHANGELOG.md > CHANGELOG.md.tmp
mv CHANGELOG.md.tmp CHANGELOG.md
echo "$NEW" > VERSION

git add CHANGELOG.md VERSION
git commit -q -m "Release $NEW"
git tag -a "v$NEW" -m "Pullse $NEW"

echo "Released $NEW locally (commit $(git rev-parse --short HEAD), tag v$NEW)."
echo "Publish it with:  git push origin main v$NEW"
