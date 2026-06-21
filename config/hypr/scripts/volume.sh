#!/bin/bash
# Output-volume control via SwayOSD with a short "pop" feedback sound.
#
# Plays the freedesktop "audio-volume-change" event on raise/lower so you hear
# the new level as you adjust it (like macOS). The sound goes through the
# default sink at the new volume, which is the point. No sound on mute toggles.
#
#   volume.sh raise|lower|mute-toggle
action="${1:-}"
[ -n "$action" ] || { echo "usage: $0 raise|lower|mute-toggle" >&2; exit 1; }

swayosd-client --output-volume "$action"

case "$action" in
    raise|lower) canberra-gtk-play -i audio-volume-change >/dev/null 2>&1 & ;;
esac
