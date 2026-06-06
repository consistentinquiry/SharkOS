#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-menu.sh"

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

# ── Power profile (power-profiles-daemon) ──────────────────

show_power_profile_menu() {
  local current; current=$(powerprofilesctl get 2>/dev/null)
  declare -A id_by_label
  local opts="" id icon label line
  while read -r id; do
    [[ -z "$id" ]] && continue
    case "$id" in
      performance) icon="󰓅"; label="Performance" ;;
      balanced)    icon="󰾅"; label="Balanced" ;;
      power-saver) icon="󰾆"; label="Power Saver" ;;
      *)           icon="󰓅"; label="$id" ;;
    esac
    line="$icon  $label"
    [[ "$id" == "$current" ]] && line+="  ← active"
    id_by_label["$line"]="$id"
    opts+="$line\n"
  done < <(powerprofilesctl list 2>/dev/null | sed -nE 's/^[ *]*([a-z-]+):$/\1/p')
  opts+="󰁍  Back"

  local sel; sel=$(menu "Power Profile" "$opts")
  case "$sel" in
    ""|*Back*) show_controls ;;
    *)
      local id="${id_by_label[$sel]}"
      [[ -n "$id" ]] && { powerprofilesctl set "$id" 2>/dev/null; notify-send -t 2000 "Power Profile" "${sel#*  }"; }
      show_controls ;;
  esac
}

# ── Audio output (PipeWire via pactl) ──────────────────────

show_audio_menu() {
  local default; default=$(pactl get-default-sink 2>/dev/null)
  declare -A name_by_label
  local opts="" name desc line
  while IFS=$'\t' read -r name desc; do
    [[ -z "$name" ]] && continue
    line="󰓃  $desc"
    [[ "$name" == "$default" ]] && line+="  ← active"
    name_by_label["$line"]="$name"
    opts+="$line\n"
  done < <(pactl list sinks 2>/dev/null | awk -F': ' '
      /^[[:space:]]*Name:/        { name=$2 }
      /^[[:space:]]*Description:/ { print name"\t"$2 }')
  opts+="󰁍  Back"

  local sel; sel=$(menu "Audio Output" "$opts")
  case "$sel" in
    ""|*Back*) show_controls ;;
    *)
      local name="${name_by_label[$sel]}"
      if [[ -n "$name" ]]; then
        pactl set-default-sink "$name" 2>/dev/null
        # Move already-playing streams to the new default sink.
        pactl list short sink-inputs 2>/dev/null | awk '{print $1}' | while read -r i; do
          [[ -n "$i" ]] && pactl move-sink-input "$i" "$name" 2>/dev/null
        done
        notify-send -t 2000 "Audio Output" "${sel#*  }"
      fi
      show_controls ;;
  esac
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

  local pp_current; pp_current=$(powerprofilesctl get 2>/dev/null)
  local pp_label="󰓅  Power Profile"
  [[ -n "$pp_current" ]] && pp_label+="  [${pp_current}]"
  pp_label+="  >"

  local audio_label="󰓃  Audio Output  >"

  local selected
  selected=$(menu "Controls" "$airplane_label\n$wifi_label\n$bt_label\n$hotspot_label\n$pp_label\n$audio_label\n󰑓  Reload UI")

  case "$selected" in
    *Airplane*)        toggle_airplane; show_controls ;;
    *WiFi*)            rfkill unblock wifi 2>/dev/null; launch_tui impala impala ;;
    *Bluetooth*)       rfkill unblock bluetooth 2>/dev/null; launch_tui bluetui bluetui ;;
    *Hotspot*)         rfkill unblock wifi 2>/dev/null; launch_tui hotspot impala --mode ap ;;
    *"Power Profile"*) show_power_profile_menu ;;
    *"Audio Output"*)  show_audio_menu ;;
    *"Reload UI"*)     "$SCRIPT_DIR/reload-ui.sh" ;;
  esac
}

show_controls
