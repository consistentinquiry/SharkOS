#!/bin/bash
# select_wallpaper.sh - Detect monitor resolution and symlink the best wallpaper
# Called by install.sh and can be re-run manually after connecting a new display

SHARKOS_DIR="${SHARKOS_DIR:-$HOME/Git/sharkOS}"
WALLPAPER_DIR="$SHARKOS_DIR/wallpaper"
TARGET="$HOME/Pictures/desktop_wallpaper.png"

# Available resolutions (widths), highest first
declare -A WALLPAPERS=(
    [3840]="desktop_wallpaper_3840x2160.png"
    [2560]="desktop_wallpaper_2560x1600.png"
    [1920]="desktop_wallpaper_1920x1080.png"
    [1366]="desktop_wallpaper_1366x768.png"
)

get_resolution() {
    # Try hyprctl first (if Hyprland is running)
    if command -v hyprctl &>/dev/null && hyprctl monitors &>/dev/null 2>&1; then
        hyprctl monitors -j | python3 -c "
import json, sys
monitors = json.load(sys.stdin)
if monitors:
    m = max(monitors, key=lambda m: m['width'])
    print(m['width'])
" 2>/dev/null && return
    fi

    # Try wlr-randr
    if command -v wlr-randr &>/dev/null; then
        wlr-randr | grep -oP '\d+x\d+' | head -1 | cut -dx -f1 && return
    fi

    # Try xrandr (XWayland fallback)
    if command -v xrandr &>/dev/null; then
        xrandr | grep '\*' | head -1 | awk '{print $1}' | cut -dx -f1 && return
    fi

    # Default to 1920
    echo "1920"
}

WIDTH=$(get_resolution)
echo "Detected monitor width: ${WIDTH}px"

# Find closest wallpaper (pick largest that doesn't exceed monitor width, or largest available)
BEST=""
for w in $(echo "${!WALLPAPERS[@]}" | tr ' ' '\n' | sort -rn); do
    if [[ $w -le $WIDTH ]]; then
        BEST="${WALLPAPERS[$w]}"
        break
    fi
done

# If monitor is smaller than all options, use the smallest
if [[ -z "$BEST" ]]; then
    BEST="${WALLPAPERS[1366]}"
fi

echo "Selected wallpaper: $BEST"

mkdir -p "$HOME/Pictures"
ln -sf "$WALLPAPER_DIR/$BEST" "$TARGET"
echo "Symlinked $TARGET -> $WALLPAPER_DIR/$BEST"
