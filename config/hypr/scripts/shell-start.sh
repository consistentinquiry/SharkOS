#!/bin/bash
# Start the shell stack matching the current theme's SHELL_KIND:
#   classic    -> waybar                    (default)
#   quickshell -> quickshell -c sharkos     (liquid-glass beta)
# Called from hyprland.conf exec-once; reload-ui.sh handles live switches.

THEMES_DIR="$HOME/.config/themes"

shell_kind() {
  local current
  current=$(cat "$THEMES_DIR/.current" 2>/dev/null || echo noir)
  local kind
  kind=$(sed -nE 's/^SHELL_KIND="?([a-z]+)"?.*/\1/p' \
    "$THEMES_DIR/$current/theme.conf" 2>/dev/null | head -n1)
  echo "${kind:-classic}"
}

qs_bin() {
  command -v quickshell || command -v qs
}

case "$(shell_kind)" in
  quickshell)
    QS=$(qs_bin)
    if [[ -n "$QS" ]]; then
      setsid "$QS" -c sharkos >/dev/null 2>&1 &
    else
      notify-send -t 4000 "SharkOS shell" "quickshell not installed — falling back to waybar"
      setsid waybar >/dev/null 2>&1 &
    fi
    ;;
  *)
    setsid waybar >/dev/null 2>&1 &
    ;;
esac
