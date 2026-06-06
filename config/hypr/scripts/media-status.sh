#!/bin/bash
# Now-playing line for the waybar custom/media module (polled).
# Prints "<icon>  Artist - Title" while a player is active; prints nothing
# when no player is running so the module collapses.

status=$(playerctl status 2>/dev/null) || exit 0
[[ -z "$status" ]] && exit 0

case "$status" in
  Playing) icon="" ;;
  Paused)  icon="" ;;
  *)       exit 0 ;;
esac

title=$(playerctl metadata --format '{{title}}' 2>/dev/null)
artist=$(playerctl metadata --format '{{artist}}' 2>/dev/null)
[[ -z "$title" && -z "$artist" ]] && exit 0

if [[ -n "$artist" ]]; then
  printf '%s  %s - %s\n' "$icon" "$artist" "$title"
else
  printf '%s  %s\n' "$icon" "$title"
fi
