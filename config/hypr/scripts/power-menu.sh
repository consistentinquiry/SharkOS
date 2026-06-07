#!/bin/bash
# Power / session menu for the SharkOS hub.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-menu.sh"

# ── Power profile (power-profiles-daemon) ──────────────────

# Only meaningful when the daemon offers 2+ switchable profiles. On desktops
# or hardware without profile support (or with the daemon absent/stopped) this
# returns false and the Power Profile entry is hidden.
power_profiles_supported() {
  command -v powerprofilesctl >/dev/null 2>&1 || return 1
  local n
  n=$(powerprofilesctl list 2>/dev/null | sed -nE 's/^[ *]*([a-z-]+):$/\1/p' | grep -c .)
  [[ "${n:-0}" -ge 2 ]]
}

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
    ""|*Back*) show_power_menu ;;
    *)
      local id="${id_by_label[$sel]}"
      [[ -n "$id" ]] && { powerprofilesctl set "$id" 2>/dev/null; notify-send -t 2000 "Power Profile" "${sel#*  }"; }
      ;;
  esac
}

# ── Power / session menu ───────────────────────────────────

show_power_menu() {
  local items=""
  if power_profiles_supported; then
    local pp_current; pp_current=$(powerprofilesctl get 2>/dev/null)
    local pp_label="󰓅  Power Profile"
    [[ -n "$pp_current" ]] && pp_label+="  [${pp_current}]"
    items+="$pp_label  >\n"
  fi
  items+="󰒲  Suspend\n󰍃  Logout\n󰜉  Restart\n󰐥  Shutdown"

  case $(menu "Power" "$items") in
    *"Power Profile"*) show_power_profile_menu ;;
    *Suspend*)         systemctl suspend ;;
    *Logout*)          hyprctl dispatch exit ;;
    *Restart*)         systemctl reboot ;;
    *Shutdown*)        systemctl poweroff ;;
  esac
}

show_power_menu
