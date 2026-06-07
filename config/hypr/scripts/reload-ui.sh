#!/bin/bash

# Skip live restarts when there's no running Hyprland session (e.g. during
# install in a TTY). The rendered configs are already written and take effect
# when the session starts.
if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && ! hyprctl version >/dev/null 2>&1; then
  echo "reload-ui: no Hyprland session; skipping live reload."
  exit 0
fi

notify-send -t 2000 "Reloading UI..." "Applying configuration changes"

# Hyprland config (safe reload, no restart)
hyprctl reload

# Notifications (swaync). Make sure the old mako daemon isn't squatting the
# org.freedesktop.Notifications bus name, start swaync if it isn't running,
# then live-reload its config + themed CSS.
pkill -x mako 2>/dev/null
if ! pgrep -x swaync >/dev/null; then
  setsid swaync >/dev/null 2>&1 &
  sleep 0.3
fi
swaync-client --reload-config 2>/dev/null
swaync-client --reload-css 2>/dev/null

# Waybar (via the launcher that adapts modules to the hardware)
pkill -x waybar
setsid "$HOME/.config/hypr/scripts/launch-waybar.sh" >/dev/null 2>&1 &

# Walker data provider + service
pkill -x elephant
pkill -f "walker.*gapplication"
sleep 0.3
setsid elephant >/dev/null 2>&1 &
setsid walker --gapplication-service >/dev/null 2>&1 &

# On-screen display (restart to pick up new style.css)
if pgrep -x swayosd-server >/dev/null; then
  pkill -x swayosd-server
  setsid swayosd-server >/dev/null 2>&1 &
fi

# Ghostty (reload config in running instances)
pkill -USR2 -x ghostty 2>/dev/null

# Wallpaper (restart to re-read hyprpaper.conf; runtime IPC is unreliable)
if pgrep -x hyprpaper >/dev/null; then
  pkill -x hyprpaper
  setsid hyprpaper >/dev/null 2>&1 &
fi

notify-send -t 2000 "UI Reloaded" "All components refreshed"
