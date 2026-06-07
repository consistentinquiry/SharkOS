#!/bin/bash
# Toggle the frosted-glass UI effect (Hyprland blur + translucent surfaces) on
# or off, independently of the active theme. Flips the glass state flag, then
# re-renders the current theme — apply-theme.sh reads the flag, forces surfaces
# opaque + disables blur when off, and reloads the UI.
STATE="$HOME/.local/state/sharkos/glass"
mkdir -p "$(dirname "$STATE")"

cur="$(cat "$STATE" 2>/dev/null || echo on)"
[[ "$cur" == "off" ]] && new="on" || new="off"
echo "$new" > "$STATE"

theme="$(cat "$HOME/.config/themes/.current" 2>/dev/null || echo noir)"
"$HOME/.config/themes/apply-theme.sh" "$theme" >/dev/null 2>&1

notify-send -t 2000 "UI Glass" "Frosted glass turned ${new}"
