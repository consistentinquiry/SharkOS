#!/bin/bash
# Waybar custom/btbattery module.
#
# Shows the battery level of a connected Bluetooth audio device (e.g. AirPods).
# Requires BlueZ "Experimental = true" in /etc/bluetooth/main.conf so bluez
# exposes the Battery1 interface (configure_bluetooth in sharkos-lib sets this);
# the device must reconnect once after that flag is enabled for the battery to
# appear. Emits JSON; the module is hidden (empty text) when nothing is
# connected or no battery is reported — waybar hides a custom module whose text
# is empty.

command -v bluetoothctl >/dev/null 2>&1 || { printf '{"text":""}\n'; exit 0; }

while read -r _ mac _; do
    [ -n "$mac" ] || continue
    info="$(bluetoothctl info "$mac" 2>/dev/null)"

    # "Battery Percentage: 0x64 (100)" -> 100
    pct="$(printf '%s\n' "$info" | sed -n 's/.*Battery Percentage:.*(\([0-9]\+\)).*/\1/p' | head -n1)"
    [ -n "$pct" ] || continue

    name="$(printf '%s\n' "$info" | sed -n 's/^[[:space:]]*Name:[[:space:]]*//p' | head -n1)"

    # Headphones glyph — guaranteed to render in JetBrainsMono Nerd Font. Swap
    # for a real AirPods SVG via a CSS background-image on #custom-btbattery if
    # you want the authentic icon (see the repo note).
    icon="󰋋"

    # Low-battery class so the stylesheet can recolour it.
    if [ "$pct" -le 20 ]; then cls="low"; else cls="ok"; fi

    printf '{"text":"%s %s%%","tooltip":"%s — %s%%","class":"%s"}\n' \
        "$icon" "$pct" "${name:-Bluetooth}" "$pct" "$cls"
    exit 0
done <<EOF
$(bluetoothctl devices Connected 2>/dev/null)
EOF

printf '{"text":""}\n'
