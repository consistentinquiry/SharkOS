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

get_bluetooth() {
  if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
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

# ── TUI launchers (WiFi / Bluetooth / Hotspot) ─────────────
# Like omarchy, WiFi/Bluetooth/Hotspot are handled by dedicated terminal TUIs
# rather than custom menus: impala (station + AP modes) and bluetui. They open
# in a floating ghostty window; the reverse-DNS --class is matched by the
# float/size window rules in hyprland.conf.
#   launch_tui <class-suffix> <command> [args...]

launch_tui() {
  local cls="$1"; shift
  setsid -f ghostty --class="com.sharkos.$cls" -e "$@" >/dev/null 2>&1
}

# ── Main controls menu ─────────────────────────────────────

show_controls() {
  # Gather current state
  local airplane_state=$(get_airplane)
  local wifi_state=$(get_wifi)
  local bt_state=$(get_bluetooth)

  # Format labels with status
  local airplane_label="󰀝  Airplane Mode"
  [[ "$airplane_state" == "on" ]] && airplane_label+="  [ON]" || airplane_label+="  [OFF]"

  # Radio on/off from rfkill; the actual connection is managed in impala.
  local wifi_label="󰤨  WiFi"
  [[ "$wifi_state" == "on" ]] && wifi_label+="  [ON]" || wifi_label+="  [OFF]"

  local bt_label="󰂯  Bluetooth"
  [[ "$bt_state" == "on" ]] && bt_label+="  [ON]" || bt_label+="  [OFF]"

  local hotspot_label="󱜠  Hotspot"

  local selected
  selected=$(menu "Controls" "$airplane_label\n$wifi_label\n$bt_label\n$hotspot_label\n󰑓  Reload UI")

  case "$selected" in
    *Airplane*)   toggle_airplane; show_controls ;;
    *WiFi*)       rfkill unblock wifi 2>/dev/null; launch_tui impala impala ;;
    *Bluetooth*)  rfkill unblock bluetooth 2>/dev/null; launch_tui bluetui bluetui ;;
    *Hotspot*)    rfkill unblock wifi 2>/dev/null; launch_tui hotspot impala --mode ap ;;
    *"Reload UI"*) "$SCRIPT_DIR/reload-ui.sh" ;;
  esac
}

show_controls
