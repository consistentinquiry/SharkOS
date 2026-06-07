#!/bin/bash
# Bump the sharkOS version in ./VERSION (SemVer MAJOR.MINOR.PATCH).
#
#   scripts/bump-version.sh [major|minor|patch]   # default: patch
#   scripts/bump-version.sh 1.2.0                  # set an explicit version
#
# Prints the new version. Bump this on every change so the waybar update
# indicator fires on other machines once you commit & push.
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
