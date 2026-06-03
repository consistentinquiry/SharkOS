#!/bin/bash
# VPN connect/disconnect handler for the Elephant Lua provider
# Usage: vpn-action.sh <type> <name> <action>
#   type: wireguard|netbird|openvpn|nordvpn
#   name: interface/connection name (or "default" for netbird/nordvpn)
#   action: connect|disconnect

TYPE="$1"
NAME="$2"
ACTION="$3"

disconnect_all() {
  # WireGuard
  if command -v wg &>/dev/null; then
    for iface in $(wg show interfaces 2>/dev/null); do
      if nmcli -t -f NAME,TYPE connection show 2>/dev/null | grep -q "^${iface}:wireguard$"; then
        nmcli con down "$iface" >/dev/null 2>&1
      else
        sudo wg-quick down "$iface" >/dev/null 2>&1
      fi
    done
    while IFS=: read -r n _; do
      nmcli con down "$n" >/dev/null 2>&1
    done < <(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep "wireguard")
  fi
  # Netbird
  if command -v netbird &>/dev/null && netbird status 2>/dev/null | grep -q "Management: Connected"; then
    netbird down >/dev/null 2>&1
  fi
  # OpenVPN via NetworkManager
  while IFS=: read -r n _; do
    nmcli con down "$n" >/dev/null 2>&1
  done < <(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep ":vpn$")
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
    wireguard)
      if nmcli -t -f NAME,TYPE connection show 2>/dev/null | grep -q "^${NAME}:wireguard$"; then
        nmcli con down "$NAME" >/dev/null 2>&1
      else
        sudo wg-quick down "$NAME" >/dev/null 2>&1
      fi
      ;;
    netbird)   netbird down >/dev/null 2>&1 ;;
    openvpn)   nmcli con down "$NAME" >/dev/null 2>&1 ;;
    nordvpn)   nordvpn disconnect >/dev/null 2>&1 ;;
  esac
  notify-send -t 2000 "VPN" "Disconnected ${NAME}"
else
  # Disconnect any active VPN first
  disconnect_all

  case "$TYPE" in
    wireguard)
      if nmcli -t -f NAME,TYPE connection show 2>/dev/null | grep -q "^${NAME}:wireguard$"; then
        nmcli con up "$NAME" >/dev/null 2>&1
      else
        sudo wg-quick up "$NAME" >/dev/null 2>&1
      fi
      ;;
    netbird)   netbird up >/dev/null 2>&1 ;;
    openvpn)   nmcli con up "$NAME" >/dev/null 2>&1 ;;
    nordvpn)   nordvpn connect >/dev/null 2>&1 ;;
  esac
  notify-send -t 2000 "VPN" "Connecting ${NAME}..."
fi
