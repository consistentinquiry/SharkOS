#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-menu.sh"

case $(menu "Menu" "󰀻  Apps\n󰸌  Themes\n󰄄  Capture\n󰕧  Screenrecord\n󰒓  Controls\n󰐥  Power") in
  *Apps*)         walker ;;
  *Themes*)       "$SCRIPT_DIR/theme-switcher.sh" ;;
  *Capture*)      "$SCRIPT_DIR/capture-menu.sh" ;;
  *Screenrecord*) "$SCRIPT_DIR/screenrecord.sh" ;;
  *Controls*)     "$SCRIPT_DIR/control-centre.sh" ;;
  *Power*)        "$SCRIPT_DIR/power-menu.sh" ;;
esac
