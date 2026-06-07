#!/bin/bash
# Waybar custom/notification source.
#
# Two things to know about the moving parts:
#
# 1. waybar HIDES a custom module whose "text" is empty (that's how the update
#    indicator auto-hides). So the bell glyph must always live inside "text" —
#    if we ever blanked it, the whole module, icon included, would disappear.
#    The unread count therefore rides as a Pango <sup> badge inside text, and
#    the waybar module renders it with escape=false.
#
# 2. `swaync-client --subscribe-waybar` streams one object per state *change*
#    and emits NOTHING on connect, so a fresh bar would have no text until the
#    first change. We print an initial snapshot (from swaync-client -c / -D),
#    then stream; both go through one jq that builds the bell + badge markup.

# jq program: turn swaync's {text=count, alt} into {text=<bell><sup>N</sup>}.
JQ='
  (.alt // "none") as $alt
  | (if ($alt | test("notification")) then "󰂚"
     elif ($alt | test("dnd")) then "󰂛"
     else "󰂜" end) as $icon
  | ((.text // "0") | tonumber? // 0) as $n
  | { text:  ($icon + (if $n > 0 then "<sup>\($n)</sup>" else "" end)),
      alt:   $alt,
      class: $alt,
      tooltip: "\($n) notification(s)" }
'

# Print a raw swaync-style {text=count, alt} object for the current state.
snapshot() {
    local count dnd alt
    count="$(swaync-client -c 2>/dev/null)"; [[ "$count" =~ ^[0-9]+$ ]] || count=0
    dnd="$(swaync-client -D 2>/dev/null)"; [ "$dnd" = "true" ] || dnd=false
    if [ "$dnd" = true ]; then
        [ "$count" -gt 0 ] && alt=dnd-notification || alt=dnd-none
    else
        [ "$count" -gt 0 ] && alt=notification || alt=none
    fi
    printf '{"text":"%s","alt":"%s"}\n' "$count" "$alt"
}

# No swaync at all (e.g. running before install): show an idle bell and stop.
if ! command -v swaync-client >/dev/null 2>&1; then
    printf '{"text":"󰂜","alt":"none","class":"none","tooltip":"0 notification(s)"}\n'
    exit 0
fi

{
    ( snapshot )                              # subshell exits -> flushes now
    swaync-client --subscribe-waybar 2>/dev/null
} | jq --unbuffered -c "$JQ"
