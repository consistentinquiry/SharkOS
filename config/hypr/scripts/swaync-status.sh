#!/bin/bash
# Waybar custom/notification source.
#
# Wraps `swaync-client --subscribe-waybar`, which streams one JSON object per
# state change ({text=count, alt=state, tooltip, class}). We pass it through jq
# to blank the count text when it's zero, so the bar shows just the bell icon
# with no "0" badge hanging off it; when there are unread notifications the
# count is rendered (as a superscript badge — see waybar config + style.css).
#
# Falls back to a static "bell, no count" object if swaync isn't running yet.
if ! command -v swaync-client >/dev/null 2>&1; then
    printf '{"text":"","alt":"none","tooltip":"","class":"none"}\n'
    exit 0
fi

swaync-client --subscribe-waybar 2>/dev/null | jq --unbuffered -c '
    .text = (if ((.text // "0") | tonumber? // 0) > 0
             then ((.text | tonumber) | tostring)
             else "" end)
'
