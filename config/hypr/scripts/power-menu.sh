#!/bin/bash
# Power / session menu for the SharkOS hub.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-menu.sh"

case $(menu "Power" "󰍁  Lock\n󰒲  Suspend\n󰍃  Logout\n󰜉  Restart\n󰐥  Shutdown") in
  *Lock*)     hyprlock ;;
  *Suspend*)  systemctl suspend ;;
  *Logout*)   hyprctl dispatch exit ;;
  *Restart*)  systemctl reboot ;;
  *Shutdown*) systemctl poweroff ;;
esac
