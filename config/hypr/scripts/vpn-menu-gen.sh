#!/bin/bash
# Generates a TOML menu file for elephant and opens walker
# This gives us brand SVG icons while using the reliable TOML menu format

MENU_FILE="$HOME/.config/elephant/menus/vpn.toml"
ICONS_DIR="$HOME/.config/hypr/icons"
SCRIPT="$HOME/.config/hypr/scripts/vpn-action.sh"

cat > "$MENU_FILE" << 'HEADER'
name = "vpn"
name_pretty = "VPN"
hide_from_providerlist = true
fixed_order = true
HEADER

echo "" >> "$MENU_FILE"

# WireGuard
if command -v wg &>/dev/null; then
  active_ifaces=$(wg show interfaces 2>/dev/null)
  # /etc/wireguard configs
  for conf in /etc/wireguard/*.conf; do
    [[ -f "$conf" ]] || continue
    iface=$(basename "$conf" .conf)
    if echo "$active_ifaces" | grep -qw "$iface"; then
      cat >> "$MENU_FILE" << EOF
[[entries]]
text = "WireGuard ($iface)  ← connected"
icon = "$ICONS_DIR/wireguard.svg"
action = "$SCRIPT wireguard $iface disconnect"
state = "current"

EOF
    else
      cat >> "$MENU_FILE" << EOF
[[entries]]
text = "WireGuard ($iface)"
icon = "$ICONS_DIR/wireguard.svg"
action = "$SCRIPT wireguard $iface connect"

EOF
    fi
  done
fi

# Netbird
if command -v netbird &>/dev/null; then
  nb_status=$(netbird status 2>/dev/null)
  if echo "$nb_status" | grep -q "Management: Connected"; then
    cat >> "$MENU_FILE" << EOF
[[entries]]
text = "Netbird  ← connected"
icon = "$ICONS_DIR/netbird.svg"
action = "$SCRIPT netbird default disconnect"
state = "current"

EOF
  else
    cat >> "$MENU_FILE" << EOF
[[entries]]
text = "Netbird"
icon = "$ICONS_DIR/netbird.svg"
action = "$SCRIPT netbird default connect"

EOF
  fi
fi

# NordVPN
if command -v nordvpn &>/dev/null; then
  nord_out=$(nordvpn status 2>/dev/null)
  if echo "$nord_out" | grep -q "Connected" && ! echo "$nord_out" | grep -q "Disconnected"; then
    city=$(echo "$nord_out" | grep "City:" | cut -d: -f2 | xargs)
    label="NordVPN  ← ${city:-connected}"
    cat >> "$MENU_FILE" << EOF
[[entries]]
text = "$label"
icon = "/usr/share/icons/hicolor/scalable/apps/nordvpn.svg"
action = "$SCRIPT nordvpn default disconnect"
state = "current"

EOF
  else
    cat >> "$MENU_FILE" << EOF
[[entries]]
text = "NordVPN"
icon = "/usr/share/icons/hicolor/scalable/apps/nordvpn.svg"
action = "$SCRIPT nordvpn default connect"

EOF
  fi
fi

# Open walker with the VPN menu
walker -m menus:vpn 2>/dev/null
