#!/bin/bash
# VPN connect/disconnect handler for the Elephant Lua provider
# Usage: vpn-action.sh <type> <name> <action>
#   type: wireguard|netbird|nordvpn
#   name: interface/connection name (or "default" for netbird/nordvpn)
#   action: connect|disconnect
#
# SharkOS runs pure iwd (no NetworkManager), so WireGuard is handled by
# wg-quick against /etc/wireguard/<name>.conf; Netbird and NordVPN use their
# own daemons. (OpenVPN/NM-WireGuard support was dropped with NetworkManager.)

TYPE="$1"
NAME="$2"
ACTION="$3"

disconnect_all() {
  # WireGuard
  if command -v wg &>/dev/null; then
    for iface in $(wg show interfaces 2>/dev/null); do
      sudo wg-quick down "$iface" >/dev/null 2>&1
    done
  fi
  # Netbird
  if command -v netbird &>/dev/null && netbird status 2>/dev/null | grep -q "Management: Connected"; then
    netbird down >/dev/null 2>&1
  fi
  # NordVPN
  if command -v nordvpn &>/dev/null; then
    local out
    out=$(nordvpn status 2>/dev/null)
    if echo "$out" | grep -q "Connected" && ! echo "$out" | grep -q "Disconnected"; then
      nordvpn disconnect >/dev/null 2>&1
    fi
  fi
  sleep 0.5
}

if [[ "$ACTION" == "disconnect" ]]; then
  case "$TYPE" in
    wireguard) sudo wg-quick down "$NAME" >/dev/null 2>&1 ;;
    netbird)   netbird down >/dev/null 2>&1 ;;
    nordvpn)   nordvpn disconnect >/dev/null 2>&1 ;;
  esac
  notify-send -t 2000 "VPN" "Disconnected ${NAME}"
else
  # Disconnect any active VPN first
  disconnect_all

  case "$TYPE" in
    wireguard) sudo wg-quick up "$NAME" >/dev/null 2>&1 ;;
    netbird)   netbird up >/dev/null 2>&1 ;;
    nordvpn)   nordvpn connect >/dev/null 2>&1 ;;
  esac
  notify-send -t 2000 "VPN" "Connecting ${NAME}..."
fi
