#!/bin/bash
# Clipboard history viewer (cliphist + walker dmenu).
# The "Clear" action sits at the TOP so it's always visible regardless of how
# long the history is. Selecting it asks for confirmation (default = Cancel)
# before wiping, so an accidental Enter can't nuke the history.

CLEAR_LABEL="󰩹  Clear clipboard history"

sel=$( { printf '%s\n' "$CLEAR_LABEL"; cliphist list; } \
  | walker --dmenu --width 500 -p "Clipboard" 2>/dev/null )

[[ -z "$sel" ]] && exit 0

if [[ "$sel" == "$CLEAR_LABEL" ]]; then
  confirm=$(printf '%s\n' "Cancel" "Yes, clear everything" \
    | walker --dmenu --width 320 -p "Clear clipboard history?" 2>/dev/null)
  if [[ "$confirm" == "Yes, clear everything" ]]; then
    cliphist wipe
    wl-copy --clear
    notify-send -t 2000 "Clipboard" "History cleared"
  fi
else
  printf '%s\n' "$sel" | cliphist decode | wl-copy
fi
