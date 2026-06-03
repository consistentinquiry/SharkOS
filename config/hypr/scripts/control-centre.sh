#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

menu() {
  local prompt="$1"
  local options="$2"
  echo -e "$options" | walker --dmenu --width 320 --minheight 1 --maxheight 400 -p "$prompt" 2>/dev/null
}

# ── Status checks ──────────────────────────────────────────

get_airplane() {
  local out
  out=$(rfkill -J 2>/dev/null)
  # If all wlan+bluetooth are soft-blocked, airplane is on
  if echo "$out" | python3 -c "
import sys, json
data = json.load(sys.stdin)
devs = data.get('rfkilldevices', data.get('', []))
radios = [d for d in devs if d.get('type') in ('wlan','bluetooth')]
print('on' if radios and all(d.get('soft')=='blocked' for d in radios) else 'off')
" 2>/dev/null | grep -q "on"; then
    echo "on"
  else
    echo "off"
  fi
}

get_wifi() {
  if rfkill -J 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
devs = data.get('rfkilldevices', data.get('', []))
wlan = [d for d in devs if d.get('type')=='wlan']
print('blocked' if wlan and all(d.get('soft')=='blocked' for d in wlan) else 'on')
" 2>/dev/null | grep -q "blocked"; then
    echo "off"
  else
    echo "on"
  fi
}

get_wifi_network() {
  nmcli -t -f NAME connection show --active 2>/dev/null | head -1
}

get_bluetooth() {
  if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
    echo "on"
  else
    echo "off"
  fi
}

get_any_vpn_active() {
  # Returns "on" if any VPN is connected, "off" otherwise
  # Check WireGuard
  if command -v wg &>/dev/null && [[ -n $(wg show 2>/dev/null) ]]; then
    echo "on"; return
  fi
  # Check Netbird
  if command -v netbird &>/dev/null && netbird status 2>/dev/null | grep -q "Connected"; then
    echo "on"; return
  fi
  # Check OpenVPN via nmcli
  if nmcli -t -f TYPE connection show --active 2>/dev/null | grep -q "vpn"; then
    echo "on"; return
  fi
  # Check NordVPN
  if command -v nordvpn &>/dev/null; then
    local out
    out=$(nordvpn status 2>/dev/null)
    if echo "$out" | grep -q "Connected" && ! echo "$out" | grep -q "Disconnected"; then
      echo "on"; return
    fi
  fi
  echo "off"
}

get_hotspot() {
  if nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep -q "802-11-wireless-hotspot"; then
    echo "on"
  else
    echo "off"
  fi
}

# ── Toggle actions ─────────────────────────────────────────

toggle_airplane() {
  if [[ $(get_airplane) == "on" ]]; then
    rfkill unblock all
  else
    rfkill block all
  fi
  sleep 0.5
}

toggle_wifi_radio() {
  if [[ $(get_wifi) == "on" ]]; then
    rfkill block wifi
  else
    rfkill unblock wifi
  fi
  sleep 0.5
}

toggle_bluetooth_power() {
  if [[ $(get_bluetooth) == "on" ]]; then
    bluetoothctl power off >/dev/null 2>&1
  else
    bluetoothctl power on >/dev/null 2>&1
  fi
  sleep 0.5
}

# ── VPN sub-menu (Elephant menu with brand SVG icons) ──────

show_vpn_menu() {
  walker -m menus:vpn 2>/dev/null
  show_controls
}

toggle_hotspot() {
  if [[ $(get_hotspot) == "on" ]]; then
    # Find and bring down the active hotspot connection
    local hotspot_name
    hotspot_name=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep "802-11-wireless-hotspot" | cut -d: -f1)
    nmcli con down "$hotspot_name" >/dev/null 2>&1
  else
    # Check if a hotspot profile already exists
    local existing
    existing=$(nmcli -t -f NAME,TYPE connection show 2>/dev/null | grep "802-11-wireless-hotspot" | cut -d: -f1)
    if [[ -n "$existing" ]]; then
      nmcli con up "$existing" >/dev/null 2>&1
    else
      # Create a new hotspot (nmcli picks SSID from hostname)
      nmcli dev wifi hotspot ifname wlan0 >/dev/null 2>&1
    fi
  fi
  sleep 1
}

# ── WiFi sub-menu ──────────────────────────────────────────

signal_icon() {
  local strength="$1"
  if   (( strength >= 67 )); then echo "󰤨"
  elif (( strength >= 33 )); then echo "󰤢"
  else                            echo "󰤟"
  fi
}

show_wifi_menu() {
  if [[ $(get_wifi) == "off" ]]; then
    case $(menu "WiFi" "󰤮  WiFi is off\n󰐊  Turn On\n󰁍  Back") in
      *"Turn On"*) rfkill unblock wifi; sleep 1; show_wifi_menu ;;
      *Back*)      show_controls ;;
    esac
    return
  fi

  local current_net
  current_net=$(get_wifi_network)

  # Scan for networks
  nmcli dev wifi rescan 2>/dev/null
  sleep 0.5

  local networks=""
  while IFS=: read -r ssid signal security; do
    [[ -z "$ssid" || "$ssid" == "--" ]] && continue
    local icon
    icon=$(signal_icon "$signal")
    local lock=""
    [[ "$security" != "" && "$security" != "--" ]] && lock=" 󰌾"
    if [[ "$ssid" == "$current_net" ]]; then
      networks+="$icon  $ssid  ← connected${lock}\n"
    else
      networks+="$icon  $ssid${lock}\n"
    fi
  done < <(nmcli -t -f SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null | sort -t: -k2 -rn | awk -F: '!seen[$1]++ {print}')

  local options="󰑓  Scan\n$networks󰖪  Turn Off\n󰁍  Back"

  local selected
  selected=$(menu "WiFi" "$options")

  case "$selected" in
    *Scan*)      show_wifi_menu ;;
    *"Turn Off"*) rfkill block wifi; sleep 0.5; show_controls ;;
    *Back*)      show_controls ;;
    *connected*) show_wifi_menu ;;  # Already connected, just refresh
    *)
      # Extract SSID (strip signal icon prefix and lock icon)
      local ssid
      ssid=$(echo "$selected" | sed 's/^..  //;s/  ← connected//;s/ 󰌾$//')
      if [[ -n "$ssid" ]]; then
        # Check if network needs password
        local security
        security=$(nmcli -t -f SSID,SECURITY dev wifi list 2>/dev/null | grep "^${ssid}:" | head -1 | cut -d: -f2)
        # Check if we have a saved connection
        if nmcli -t -f NAME connection show 2>/dev/null | grep -qx "$ssid"; then
          nmcli con up "$ssid" >/dev/null 2>&1
          notify-send -t 2000 "WiFi" "Connected to $ssid"
        elif [[ -n "$security" && "$security" != "--" && "$security" != "" ]]; then
          local password
          password=$(echo "" | walker --dmenu --width 300 --minheight 1 --maxheight 1 -x -p "Password for $ssid" 2>/dev/null)
          if [[ -n "$password" ]]; then
            if nmcli dev wifi connect "$ssid" password "$password" >/dev/null 2>&1; then
              notify-send -t 2000 "WiFi" "Connected to $ssid"
            else
              notify-send -t 3000 "WiFi" "Failed to connect to $ssid"
            fi
          fi
        else
          nmcli dev wifi connect "$ssid" >/dev/null 2>&1
          notify-send -t 2000 "WiFi" "Connected to $ssid"
        fi
      fi
      show_controls
      ;;
  esac
}

# ── Bluetooth sub-menu ─────────────────────────────────────

show_bluetooth_menu() {
  if [[ $(get_bluetooth) == "off" ]]; then
    case $(menu "Bluetooth" "󰂲  Bluetooth is off\n󰐊  Turn On\n󰁍  Back") in
      *"Turn On"*) bluetoothctl power on >/dev/null 2>&1; sleep 0.5; show_bluetooth_menu ;;
      *Back*)      show_controls ;;
    esac
    return
  fi

  # List paired devices with connection status
  local devices=""
  while read -r _ mac name; do
    [[ -z "$mac" ]] && continue
    local connected=""
    if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
      connected="  ← connected"
      devices+="󰂱  $name$connected\n"
    else
      devices+="󰂯  $name\n"
    fi
  done < <(bluetoothctl devices 2>/dev/null)

  local options="󰑓  Scan for devices\n$devices  Turn Off\n󰁍  Back"

  local selected
  selected=$(menu "Bluetooth" "$options")

  case "$selected" in
    *"Scan"*)
      notify-send -t 3000 "Bluetooth" "Scanning for devices..."
      bluetoothctl --timeout 4 scan on >/dev/null 2>&1
      show_bluetooth_menu
      ;;
    *"Turn Off"*)
      bluetoothctl power off >/dev/null 2>&1
      sleep 0.5
      show_controls
      ;;
    *Back*)
      show_controls
      ;;
    *connected*)
      # Disconnect the device
      local dev_name
      dev_name=$(echo "$selected" | sed 's/^...  //;s/  ← connected$//')
      local mac
      mac=$(bluetoothctl devices 2>/dev/null | grep "$dev_name" | awk '{print $2}')
      if [[ -n "$mac" ]]; then
        bluetoothctl disconnect "$mac" >/dev/null 2>&1
        notify-send -t 2000 "Bluetooth" "Disconnected $dev_name"
      fi
      sleep 0.5
      show_bluetooth_menu
      ;;
    *)
      # Connect to device
      local dev_name
      dev_name=$(echo "$selected" | sed 's/^...  //')
      local mac
      mac=$(bluetoothctl devices 2>/dev/null | grep "$dev_name" | awk '{print $2}')
      if [[ -n "$mac" ]]; then
        notify-send -t 2000 "Bluetooth" "Connecting to $dev_name..."
        bluetoothctl connect "$mac" >/dev/null 2>&1
        sleep 1
        if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
          notify-send -t 2000 "Bluetooth" "Connected to $dev_name"
        else
          notify-send -t 3000 "Bluetooth" "Failed to connect to $dev_name"
        fi
      fi
      show_bluetooth_menu
      ;;
  esac
}

# ── Main controls menu ─────────────────────────────────────

show_controls() {
  # Gather current state
  local airplane_state=$(get_airplane)
  local wifi_state=$(get_wifi)
  local bt_state=$(get_bluetooth)
  local vpn_state=$(get_any_vpn_active)
  local hotspot_state=$(get_hotspot)

  # Format labels with status
  local airplane_label="󰀝  Airplane Mode"
  [[ "$airplane_state" == "on" ]] && airplane_label+="  [ON]" || airplane_label+="  [OFF]"

  local wifi_label="󰤨  WiFi"
  if [[ "$wifi_state" == "on" ]]; then
    local net=$(get_wifi_network)
    [[ -n "$net" ]] && wifi_label+="  [$net]" || wifi_label+="  [ON]"
  else
    wifi_label+="  [OFF]"
  fi
  wifi_label+="  >"

  local bt_label="󰂯  Bluetooth"
  [[ "$bt_state" == "on" ]] && bt_label+="  [ON]" || bt_label+="  [OFF]"
  bt_label+="  >"

  local vpn_label="󰌆  VPN"
  [[ "$vpn_state" == "on" ]] && vpn_label+="  [ON]" || vpn_label+="  [OFF]"
  vpn_label+="  >"

  local hotspot_label="󱜠  Hotspot"
  [[ "$hotspot_state" == "on" ]] && hotspot_label+="  [ON]" || hotspot_label+="  [OFF]"

  local selected
  selected=$(menu "Controls" "$airplane_label\n$wifi_label\n$bt_label\n$vpn_label\n$hotspot_label\n󰑓  Reload UI")

  case "$selected" in
    *Airplane*)   toggle_airplane; show_controls ;;
    *WiFi*)       show_wifi_menu ;;
    *Bluetooth*)  show_bluetooth_menu ;;
    *VPN*)        show_vpn_menu ;;
    *Hotspot*)    toggle_hotspot; show_controls ;;
    *"Reload UI"*) "$SCRIPT_DIR/reload-ui.sh" ;;
  esac
}

show_controls
