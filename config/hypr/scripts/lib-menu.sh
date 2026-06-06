#!/bin/bash
# Shared walker dmenu helpers for the SharkOS hub menus.
#
# The dropdown auto-grows to fit its content but is capped at ~85% of the
# focused monitor's logical height. Short menus (the hub and its sub-menus)
# therefore never scroll, while the cap still scales with the screen so a
# long list can't overflow a small display. This is NOT used by the apps
# launcher (the bare `walker` call), which intentionally caps and scrolls.

# Max scrolled-content height in px: ~85% of the focused monitor's logical
# height (pixel height / scale). Falls back to 900 if hyprctl/jq aren't there.
menu_maxheight() {
  local h
  h=$(hyprctl monitors -j 2>/dev/null | jq -r 'first(.[] | select(.focused)) | (.height / .scale)' 2>/dev/null)
  case "$h" in ''|null) h=900 ;; esac
  awk "BEGIN { v = $h * 0.85; printf \"%d\", (v < 1 ? 1 : v) }"
}

# menu <prompt> <newline-separated options> [extra walker args...]
menu() {
  local prompt="$1" options="$2"
  shift 2
  echo -e "$options" | walker --dmenu --width 320 --minheight 1 --maxheight "$(menu_maxheight)" -p "$prompt" "$@" 2>/dev/null
}
