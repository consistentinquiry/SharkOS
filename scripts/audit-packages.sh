#!/bin/bash
# Audit drift between the curated package lists and what's actually installed.
# Does NOT modify the lists — the curated pacman.txt / aur.txt stay the source of truth.
#
#   installed-but-unlisted -> consider adding to the list
#   listed-but-not-installed -> stale entry, or not yet installed
set -euo pipefail

DIR="$(cd "$(dirname "$0")/../packages" && pwd)"

listed() { grep -vE '^\s*#|^\s*$' "$1" | sort -u; }

echo "── Official (pacman) ───────────────────────────────"
comm -23 <(pacman -Qqen | sort -u) <(listed "$DIR/pacman.txt") \
  | sed 's/^/  + installed, not in pacman.txt: /'
comm -13 <(pacman -Qqen | sort -u) <(listed "$DIR/pacman.txt") \
  | sed 's/^/  - in pacman.txt, not installed: /'

echo "── AUR (foreign) ───────────────────────────────────"
comm -23 <(pacman -Qqem | sort -u) <(listed "$DIR/aur.txt") \
  | sed 's/^/  + installed, not in aur.txt: /'
comm -13 <(pacman -Qqem | sort -u) <(listed "$DIR/aur.txt") \
  | sed 's/^/  - in aur.txt, not installed: /'

echo "────────────────────────────────────────────────────"
echo "Edit packages/{pacman,aur}.txt by hand to keep grouping/comments intact."
