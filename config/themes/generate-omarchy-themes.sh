#!/bin/bash
# Generate theme.conf files for this theming system from Omarchy's colors.toml palettes.
#
# Usage: generate-omarchy-themes.sh [path-to-omarchy-repo]
#
# Reads each <repo>/themes/<name>/colors.toml and writes
# ~/.config/themes/omarchy-<name>/theme.conf in this system's variable schema.
# Re-runnable: regenerates all omarchy-* themes, leaving hand-made themes (e.g. noir) untouched.

set -euo pipefail

OMARCHY_REPO="${1:-$HOME/Git/omarchy}"
SRC="$OMARCHY_REPO/themes"
DEST="$HOME/.config/themes"

if [[ ! -d "$SRC" ]]; then
  echo "Omarchy themes dir not found: $SRC" >&2
  exit 1
fi

# --- helpers ----------------------------------------------------------------

# Read a "#rrggbb" value for a key out of a colors.toml file.
toml_get() {
  local file="$1" key="$2"
  sed -nE "s/^${key}[[:space:]]*=[[:space:]]*[\"']?#?([0-9a-fA-F]{6})[\"']?.*/\1/p" "$file" | head -n1
}

# "rrggbb" -> "r, g, b"
hex_rgb() {
  local h="${1#\#}"
  printf '%d, %d, %d' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"
}

# rgba string from hex + alpha float, e.g. rgba(122, 162, 247, 0.25)
rgba() { printf 'rgba(%s, %s)' "$(hex_rgb "$1")" "$2"; }

# Title-case a kebab slug: "tokyo-night" -> "Tokyo Night"
pretty() {
  echo "$1" | sed -E 's/(^|-)([a-z])/\1\u\2/g; s/-/ /g'
}

# --- generation -------------------------------------------------------------

count=0
for dir in "$SRC"/*/; do
  name="$(basename "$dir")"
  colors="$dir/colors.toml"
  [[ -f "$colors" ]] || { echo "skip $name (no colors.toml)"; continue; }

  # Core palette
  bg="$(toml_get "$colors" background)"
  fg="$(toml_get "$colors" foreground)"
  accent="$(toml_get "$colors" accent)"
  cursor="$(toml_get "$colors" cursor)"
  sel_bg="$(toml_get "$colors" selection_background)"
  sel_fg="$(toml_get "$colors" selection_foreground)"

  # Sensible fallbacks
  : "${accent:=$fg}"
  : "${cursor:=$fg}"
  : "${sel_bg:=$accent}"
  : "${sel_fg:=$fg}"

  declare -A C
  local_missing=0
  for i in $(seq 0 15); do
    C[$i]="$(toml_get "$colors" "color$i")"
    [[ -z "${C[$i]}" ]] && local_missing=1
  done
  if [[ -z "$bg" || -z "$fg" || "$local_missing" == 1 ]]; then
    echo "skip $name (incomplete palette)"; continue
  fi

  out_dir="$DEST/omarchy-$name"
  mkdir -p "$out_dir"

  # Copy the theme's default wallpaper (first background, ignoring the omarchy.png logo)
  # into the theme dir so the theme is self-contained.
  wallpaper=""
  if [[ -d "$dir/backgrounds" ]]; then
    src_bg="$(find "$dir/backgrounds" -maxdepth 1 -type f ! -name 'omarchy.png' \
              \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
              | sort | head -n1)"
    if [[ -n "$src_bg" ]]; then
      rm -f "$out_dir"/background.*
      ext="${src_bg##*.}"
      cp -f "$src_bg" "$out_dir/background.$ext"
      wallpaper="$out_dir/background.$ext"
    fi
  fi

  cat >"$out_dir/theme.conf" <<EOF
# Generated from Omarchy theme '$name' — do not edit by hand.
# Regenerate with: ~/.config/themes/generate-omarchy-themes.sh
THEME_NAME="Omarchy $(pretty "$name")"

# Hyprland borders (rgba hex without #)
BORDER_ACTIVE="${accent}ee"
BORDER_INACTIVE="${fg}30"

# Window backgrounds
WINDOW_BG="$(rgba "$bg" 0.55)"
WINDOW_BG_SOLID="$(rgba "$bg" 0.85)"

# Accent-tinted surfaces
ACCENT_HEX="#${accent}"
ACCENT_BG="$(rgba "$accent" 0.20)"
ACCENT_SEL="$(rgba "$accent" 0.15)"

# Foreground & overlays (derived from fg so they work on light + dark)
FG_COLOR="#${fg}"
FG_RGBA="$(rgba "$fg" 0.9)"
FG_SOFT="$(rgba "$fg" 0.7)"
FG_SOFT2="$(rgba "$fg" 0.65)"
FG_DIM="$(rgba "$fg" 0.35)"
FG_MUTED="$(rgba "$fg" 0.25)"
OVERLAY_SOFT="$(rgba "$fg" 0.08)"
OVERLAY_HOVER="$(rgba "$fg" 0.10)"
HAIRLINE="$(rgba "$fg" 0.12)"
BORDER_CSS="$(rgba "$fg" 0.25)"
BORDER_FOCUS="$(rgba "$fg" 0.4)"
BORDER_CSS_STRONG="$(rgba "$fg" 0.8)"

# Status colors
ERROR_BG="#${C[1]}"
ERROR_FG="#ffffff"
ERROR_RGBA="$(rgba "${C[1]}" 0.8)"
ERROR_BG_SOFT="$(rgba "${C[1]}" 0.25)"
SUCCESS="$(rgba "${C[2]}" 0.85)"
SUCCESS_BRIGHT="$(rgba "${C[2]}" 1)"
SUCCESS_DIM="$(rgba "${C[2]}" 0.7)"
WARN="$(rgba "${C[3]}" 0.9)"
WARN_BRIGHT="$(rgba "${C[3]}" 1)"
CRIT="$(rgba "${C[1]}" 0.9)"
CRIT_BRIGHT="$(rgba "${C[1]}" 1)"

# Terminal palette
COLOR_BG="${bg}"
COLOR_FG="${fg}"
COLOR_CURSOR="${cursor}"
COLOR_SELECTION_BG="${sel_bg}"
COLOR_SELECTION_FG="${sel_fg}"
COLOR_0="${C[0]}"
COLOR_1="${C[1]}"
COLOR_2="${C[2]}"
COLOR_3="${C[3]}"
COLOR_4="${C[4]}"
COLOR_5="${C[5]}"
COLOR_6="${C[6]}"
COLOR_7="${C[7]}"
COLOR_8="${C[8]}"
COLOR_9="${C[9]}"
COLOR_10="${C[10]}"
COLOR_11="${C[11]}"
COLOR_12="${C[12]}"
COLOR_13="${C[13]}"
COLOR_14="${C[14]}"
COLOR_15="${C[15]}"

# Corner radius — Omarchy's aesthetic is squared
RADIUS_BAR="0px"
RADIUS_BTN="0px"
RADIUS_CLOCK="0px"
RADIUS_POPOVER="0px"
RADIUS_WRAPPER="0px"
RADIUS_MD="0px"
RADIUS_QUICK="0px"
RADIUS_KEYBIND="0px"

# Mako
MAKO_BG="#${bg}E6"
MAKO_TEXT="#${fg}"
MAKO_BORDER="#${accent}CC"
MAKO_RADIUS=16

# Hyprlock
LOCK_OUTER="rgba(${accent}cc)"
LOCK_INNER="rgb(${bg})"
LOCK_FONT="rgb(${fg})"
LOCK_FAIL="rgba(${C[1]}, 0.9)"
LOCK_CAPS="rgba(${C[3]}, 0.9)"
LOCK_PLACEHOLDER_FG="${fg}a6"

# Wallpaper (empty = leave current wallpaper unchanged)
WALLPAPER="${wallpaper}"
EOF

  count=$((count + 1))
  echo "generated omarchy-$name -> Omarchy $(pretty "$name")"
done

echo "Done. $count theme(s) written to $DEST."
