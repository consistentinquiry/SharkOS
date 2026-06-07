#!/bin/bash
# Open `sharkos-update` in a floating terminal that stays up after it finishes,
# so its output (and any "commit your changes first" error) is readable.
# Shared by the waybar update indicator (on-click) and the hub menu.
# Matched by the com.sharkos.update window rule in hyprland.conf.
exec setsid -f ghostty --class="com.sharkos.update" \
    -e bash -lc 'sharkos-update; echo; read -rp "Press Enter to close..."' \
    >/dev/null 2>&1
