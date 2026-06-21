#!/bin/bash
# Launch Steam with its desktop UI scaled to the current monitor scale, so the
# X11/XWayland client renders crisply on fractionally-scaled displays.
#
# Pairs with `xwayland { force_zero_scaling = true }` in hyprland.conf, which
# makes X11 apps render at native resolution (sharp) but at logical scale 1 (so
# they'd otherwise appear too small). STEAM_FORCE_DESKTOPUI_SCALING brings the
# Steam UI back to the right size while staying crisp.
#
# The scale is read live from Hyprland's focused monitor, so this is correct on
# any machine without hardcoding a value. Falls back to 1 if it can't be read.
scale="$(hyprctl monitors -j 2>/dev/null \
  | jq -r 'first(.[] | select(.focused)).scale // .[0].scale // 1' 2>/dev/null)"
[[ "$scale" =~ ^[0-9]+(\.[0-9]+)?$ ]] || scale=1

exec env STEAM_FORCE_DESKTOPUI_SCALING="$scale" /usr/bin/steam "$@"
