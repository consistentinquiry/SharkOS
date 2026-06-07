#!/bin/bash
# Manually check for a sharkOS update right now, instead of waiting for the
# waybar module's 30-minute interval.
#
# Delegates to sharkos-update-check.sh, which does the git fetch, fires a
# deduped desktop notification when a newer version exists, and emits the JSON
# the waybar indicator consumes. We then nudge waybar so the bar reflects the
# result immediately, and print a human-readable line for terminal use.
#
# Bindable to a key, callable from the hub menu, or run straight from a shell.
set -u

REPO="${SHARKOS_DIR:-$HOME/Git/sharkOS}"
STATE="${SHARKOS_STATE:-$HOME/.local/state/sharkos}/version"
HERE="$(cd "$(dirname "$0")" && pwd)"

# The check script fetches origin, notifies (once per version) and prints JSON.
out="$(bash "$HERE/sharkos-update-check.sh")"

# Refresh the visible indicator now rather than at the next interval tick.
pkill -RTMIN+9 waybar 2>/dev/null

running="0.0.0"
[ -f "$STATE" ] && running="$(tr -d '[:space:]' < "$STATE")"
latest="$(git -C "$REPO" show origin/main:VERSION 2>/dev/null | tr -d '[:space:]')"
[ -n "$latest" ] || { [ -f "$REPO/VERSION" ] && latest="$(tr -d '[:space:]' < "$REPO/VERSION")"; }
[ -n "$latest" ] || latest="$running"

if printf '%s' "$out" | grep -q 'update-available'; then
    echo "sharkOS update available: $running → $latest (run sharkos-update)"
else
    echo "sharkOS is up to date ($running)."
fi
