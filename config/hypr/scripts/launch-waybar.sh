#!/bin/bash
# Launch waybar, dropping the battery module on machines without a battery
# (e.g. desktops). The committed waybar config stays the canonical laptop
# layout; this adapts it at runtime so the same SharkOS image works on any
# machine. Battery presence is detected via /sys/class/power_supply/BAT*.

CFG="$HOME/.config/waybar/config"
STYLE="$HOME/.config/waybar/style.css"
RUNTIME="${XDG_RUNTIME_DIR:-/tmp}/sharkos-waybar.json"

if compgen -G "/sys/class/power_supply/BAT*" >/dev/null; then
  # Battery present — use the config unchanged.
  exec waybar -c "$CFG" -s "$STYLE"
fi

# No battery: strip "battery" from modules-right (and its block). Fall back to
# the unmodified config if jq is missing or the rewrite fails.
if command -v jq >/dev/null 2>&1 \
   && jq '(.["modules-right"] |= map(select(. != "battery"))) | del(.battery)' "$CFG" > "$RUNTIME" 2>/dev/null; then
  exec waybar -c "$RUNTIME" -s "$STYLE"
fi

exec waybar -c "$CFG" -s "$STYLE"
