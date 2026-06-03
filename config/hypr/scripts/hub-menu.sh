#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

menu() {
  local prompt="$1"
  local options="$2"
  echo -e "$options" | walker --dmenu --width 300 --minheight 1 --maxheight 300 -p "$prompt" 2>/dev/null
}

case $(menu "Menu" "󰀻  Apps\n󰸌  Themes\n󰒓  Controls") in
  *Apps*)      walker ;;
  *Themes*)    "$SCRIPT_DIR/theme-switcher.sh" ;;
  *Controls*)  "$SCRIPT_DIR/control-centre.sh" ;;
esac
