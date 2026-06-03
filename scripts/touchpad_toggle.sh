#!/bin/bash
# Toggle touchpad on/off for Hyprland
# Bound to XF86TouchpadToggle in hyprland.conf

HYPRCTL="hyprctl"
DEVICE=$(${HYPRCTL} devices -j | python3 -c "
import json, sys
devices = json.load(sys.stdin)
for d in devices.get('mice', []):
    name = d.get('name', '').lower()
    if 'touchpad' in name or 'trackpad' in name:
        print(d['name'])
        break
" 2>/dev/null)

if [[ -z "$DEVICE" ]]; then
    notify-send "Touchpad" "No touchpad device found"
    exit 1
fi

# Check current state
ENABLED=$(${HYPRCTL} devices -j | python3 -c "
import json, sys
devices = json.load(sys.stdin)
for d in devices.get('mice', []):
    if d.get('name') == '${DEVICE}':
        # sendEvents: true = enabled
        print('1' if d.get('sendEvents', True) else '0')
        break
" 2>/dev/null)

if [[ "$ENABLED" == "1" ]]; then
    ${HYPRCTL} keyword "device[${DEVICE}]:enabled" false
    notify-send "Touchpad" "Disabled"
else
    ${HYPRCTL} keyword "device[${DEVICE}]:enabled" true
    notify-send "Touchpad" "Enabled"
fi
