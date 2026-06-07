#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-menu.sh"

case $(menu "Menu" "󰀻  Apps\n󰸌  Themes\n󰄄  Capture\n󰕧  Screenrecord\n󰒓  Controls\n󰅢  Update\n󰍁  Lock\n󰐥  Power") in
  *Apps*)         walker ;;
  *Themes*)       "$SCRIPT_DIR/theme-switcher.sh" ;;
  *Capture*)      "$SCRIPT_DIR/capture-menu.sh" ;;
  *Screenrecord*) "$SCRIPT_DIR/screenrecord.sh" ;;
  *Controls*)     "$SCRIPT_DIR/control-centre.sh" ;;
  # Run the sync in a floating terminal that stays open so its output (and any
  # "commit your changes first" error) is readable. Matched by the
  # com.sharkos.update window rule in hyprland.conf.
  *Update*)       setsid -f ghostty --class="com.sharkos.update" \
                    -e bash -lc 'sharkos-update; echo; read -rp "Press Enter to close..."' \
                    >/dev/null 2>&1 ;;
  *Lock*)         hyprlock ;;
  *Power*)        "$SCRIPT_DIR/power-menu.sh" ;;
esac
