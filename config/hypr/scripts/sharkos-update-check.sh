#!/bin/bash
# Waybar custom/update module source.
#
# Emits JSON describing whether a sharkOS update is available. The module is
# hidden whenever the running version matches the latest, because waybar hides
# a custom module whose "text" is empty.
#
#   running  = the version this machine last applied (state file written by
#              record_version() at the end of install.sh / update.sh)
#   latest   = the version origin/main advertises (best-effort fetch), falling
#              back to the local working-tree VERSION when offline, and finally
#              to `running` so we never raise a false alarm.

REPO="${SHARKOS_DIR:-$HOME/Git/sharkOS}"
STATE="${SHARKOS_STATE:-$HOME/.local/state/sharkos}/version"

running=""
[ -f "$STATE" ] && running="$(tr -d '[:space:]' < "$STATE")"
[ -n "$running" ] || running="0.0.0"

latest=""
if [ -d "$REPO/.git" ]; then
    # Update remote-tracking refs without touching the working tree. Time-boxed
    # so a slow/offline network can't stall the bar.
    timeout 8 git -C "$REPO" fetch --quiet origin main 2>/dev/null
    latest="$(git -C "$REPO" show origin/main:VERSION 2>/dev/null | tr -d '[:space:]')"
fi
# Offline fallback: whatever the local checkout knows (catches a local bump too).
[ -n "$latest" ] || { [ -f "$REPO/VERSION" ] && latest="$(tr -d '[:space:]' < "$REPO/VERSION")"; }
[ -n "$latest" ] || latest="$running"

if [ "$running" != "$latest" ]; then
    printf '{"text":"󰚰","tooltip":"sharkOS update available\\n%s → %s\\nClick to update","class":"update-available"}\n' \
        "$running" "$latest"
else
    printf '{"text":"","tooltip":"","class":"up-to-date"}\n'
fi
