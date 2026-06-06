#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-menu.sh"

THEMES_DIR="$HOME/.config/themes"
current=$(cat "$THEMES_DIR/.current" 2>/dev/null || echo "noir")

# Build menu from directories containing theme.conf.
# Display each theme's pretty THEME_NAME, but remember its directory name as the key.
declare -A by_label
lines=()
for dir in "$THEMES_DIR"/*/; do
  [[ -f "$dir/theme.conf" ]] || continue
  key=$(basename "$dir")

  # Pull the human label from theme.conf (THEME_NAME="..."), fall back to the dir name.
  label=$(sed -nE 's/^THEME_NAME="?([^"]+)"?.*/\1/p' "$dir/theme.conf" | head -n1)
  [[ -n "$label" ]] || label="$key"

  by_label["$label"]="$key"
  if [[ "$key" == "$current" ]]; then
    lines+=("  $label  ← current")
  else
    lines+=("  $label")
  fi
done

if [[ ${#lines[@]} -eq 0 ]]; then
  notify-send -t 2000 "Themes" "No themes found in $THEMES_DIR"
  exit 0
fi

# Emit one clean line per theme (sorted, no stray blank lines) to walker's dmenu.
selected=$(printf '%s\n' "${lines[@]}" | sort | walker --dmenu --width 320 --minheight 1 --maxheight "$(menu_maxheight)" -p "Theme" 2>/dev/null)

# Strip leading whitespace and the current marker, leaving the label
selected=$(echo "$selected" | sed 's/^[[:space:]]*//; s/[[:space:]]*← current$//; s/[[:space:]]*$//')
[[ -n "$selected" ]] || exit 0

key="${by_label[$selected]}"
if [[ -n "$key" && -d "$THEMES_DIR/$key" ]]; then
  "$THEMES_DIR/apply-theme.sh" "$key"
fi
