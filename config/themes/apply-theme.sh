#!/bin/bash
# Theme application engine
# Usage: apply-theme.sh <theme-name>

THEME="$1"
THEMES_DIR="$HOME/.config/themes"
THEME_DIR="$THEMES_DIR/$THEME"

if [[ -z "$THEME" || ! -f "$THEME_DIR/theme.conf" ]]; then
  notify-send -t 3000 "Theme Error" "Theme '$THEME' not found"
  exit 1
fi

# Source the theme variables
source "$THEME_DIR/theme.conf"

apply_template() {
  local tpl="$1"
  local target="$2"
  local content
  content=$(<"$tpl")

  # Replace all {{VAR}} with the value of $VAR
  local var
  while [[ "$content" =~ \{\{([A-Za-z_0-9]+)\}\} ]]; do
    var="${BASH_REMATCH[1]}"
    content="${content//"{{$var}}"/"${!var}"}"
  done

  echo "$content" > "$target"
}

notify-send -t 2000 "Applying theme..." "${THEME_NAME:-$THEME}"

# Apply each template
apply_template "$THEMES_DIR/templates/walker-style.css.tpl" \
  "$HOME/.config/walker/themes/noir/style.css"

apply_template "$THEMES_DIR/templates/hyprland-colors.conf.tpl" \
  "$HOME/.config/hypr/colors.conf"

apply_template "$THEMES_DIR/templates/waybar-style.css.tpl" \
  "$HOME/.config/waybar/style.css"

apply_template "$THEMES_DIR/templates/swaync.css.tpl" \
  "$HOME/.config/swaync/style.css"

apply_template "$THEMES_DIR/templates/jolt.toml.tpl" \
  "$HOME/.config/jolt/themes/sharkos.toml"

apply_template "$THEMES_DIR/templates/ghostty.conf.tpl" \
  "$HOME/.config/ghostty/config"

apply_template "$THEMES_DIR/templates/hyprlock.conf.tpl" \
  "$HOME/.config/hypr/hyprlock.conf"

apply_template "$THEMES_DIR/templates/swayosd-style.css.tpl" \
  "$HOME/.config/swayosd/style.css"

# Set the theme's wallpaper, if it defines one (empty = leave current wallpaper alone)
if [[ -n "${WALLPAPER:-}" && -f "$WALLPAPER" ]]; then
  # Persist for next login
  cat > "$HOME/.config/hypr/hyprpaper.conf" <<EOF
preload = $WALLPAPER

wallpaper {
    monitor =
    path = $WALLPAPER
}
splash = false
EOF
  # hyprpaper is restarted by reload-ui.sh below to pick up this config.
fi

# Record current theme
echo "$THEME" > "$THEMES_DIR/.current"

# Reload all UI components
"$HOME/.config/hypr/scripts/reload-ui.sh"
