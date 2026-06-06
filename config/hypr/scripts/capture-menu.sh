#!/bin/bash
# Screenshot + colour-picker menu for the SharkOS hub.
# Screenshots open in swappy: annotate there, then Ctrl+S saves and Ctrl+C
# copies. Save dir / filename come from ~/.config/swappy/config
# (save_dir = ~/Pictures/Screenshots).
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-menu.sh"

mkdir -p "$HOME/Pictures/Screenshots"

# Capture the given geometry ("x,y WxH"; empty = full screen) and open it in
# the swappy viewer/editor.
shot() {
  local geom="$1"
  if [[ -n "$geom" ]]; then
    grim -g "$geom" - | swappy -f -
  else
    grim - | swappy -f -
  fi
}

case $(menu "Capture" "  Region\n  Window\n󰍹  Full screen\n󰈉  Colour picker") in
  *Region*)
    geom=$(slurp 2>/dev/null) || exit 0
    [[ -n "$geom" ]] && shot "$geom"
    ;;
  *Window*)
    shot "$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')"
    ;;
  *"Full screen"*)
    shot ""
    ;;
  *"Colour picker"*)
    # hyprpicker -a copies the hex to the clipboard; capture it for the toast.
    color=$(hyprpicker -a 2>/dev/null)
    [[ -n "$color" ]] && notify-send -t 2500 "Colour copied" "$color"
    ;;
esac
