#!/bin/bash
# Toggle a SharkOS UI effect flag on/off and re-apply the current theme so the
# render picks it up. Each flag is an independent state file.
#
#   ui-toggle.sh <flag> [pretty-label]
#     glass           — frosted glass (translucent surfaces)
#     elephant-focus  — blur the desktop behind the walker launcher
key="$1"
label="${2:-$1}"
[[ -z "$key" ]] && { echo "usage: ui-toggle.sh <flag> [label]" >&2; exit 1; }

STATE="$HOME/.local/state/sharkos/$key"
mkdir -p "$(dirname "$STATE")"

cur="$(cat "$STATE" 2>/dev/null || echo on)"
[[ "$cur" == "off" ]] && new="on" || new="off"
echo "$new" > "$STATE"

theme="$(cat "$HOME/.config/themes/.current" 2>/dev/null || echo noir)"
"$HOME/.config/themes/apply-theme.sh" "$theme" >/dev/null 2>&1

notify-send -t 2000 "$label" "$label turned $new"
