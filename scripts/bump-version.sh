#!/bin/bash
# Bump the sharkOS version in ./VERSION (SemVer MAJOR.MINOR.PATCH).
#
#   scripts/bump-version.sh [major|minor|patch]   # default: patch
#   scripts/bump-version.sh 1.2.0                  # set an explicit version
#   scripts/bump-version.sh patch --tag           # bump + commit + tag a release
#
# Prints the new version. Bump this on every change so the waybar update
# indicator fires on other machines. Stable-channel consumers only pick up
# *tagged* releases, so use --tag (then `git push --follow-tags`) to ship.
set -euo pipefail
cd "$(dirname "$0")/.."

cur="$(tr -d '[:space:]' < VERSION 2>/dev/null || echo 0.0.0)"
IFS=. read -r major minor patch <<<"$cur"

arg="${1:-patch}"
case "$arg" in
    major) major=$((major + 1)); minor=0; patch=0 ;;
    minor) minor=$((minor + 1)); patch=0 ;;
    patch) patch=$((patch + 1)) ;;
    [0-9]*.[0-9]*.[0-9]*) new="$arg" ;;
    *) echo "Usage: $0 [major|minor|patch|X.Y.Z]" >&2; exit 1 ;;
esac
new="${new:-$major.$minor.$patch}"

printf '%s\n' "$new" > VERSION
echo "VERSION: $cur -> $new"

# `bump-version.sh <level|X.Y.Z> --tag`: commit the bump and create the matching
# release tag, so the `stable` channel picks it up. Edge boxes already track
# main and see the change without a tag.
if [[ "${2:-}" == "--tag" ]]; then
    git add VERSION
    git commit -m "Release $new"
    git tag -a "v$new" -m "sharkOS $new"
    echo "Tagged v$new — push with: git push --follow-tags"
fi
