#!/bin/bash
# Screen recording toggle for the SharkOS hub (wf-recorder).
# Run once to start (pick region/full ± audio), run again to stop & save.
# Recordings go to ~/Videos/Screenrecordings.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-menu.sh"

# Already recording? Stop cleanly (SIGINT lets wf-recorder finalise the file).
if pgrep -x wf-recorder >/dev/null; then
  pkill -INT -x wf-recorder
  notify-send -t 2500 "Screen recording" "Stopped — saved to ~/Videos/Screenrecordings"
  exit 0
fi

DIR="$HOME/Videos/Screenrecordings"
mkdir -p "$DIR"

args=()
case $(menu "Screenrecord" "  Region\n󰍹  Full screen\n  Region + audio\n󰍹  Full + audio") in
  *"Region + audio"*) geom=$(slurp 2>/dev/null) || exit 0; [[ -n "$geom" ]] || exit 0; args=(-g "$geom" --audio) ;;
  *"Full + audio"*)   args=(--audio) ;;
  *Region*)           geom=$(slurp 2>/dev/null) || exit 0; [[ -n "$geom" ]] || exit 0; args=(-g "$geom") ;;
  *"Full screen"*)    args=() ;;
  *)                  exit 0 ;;
esac

file="$DIR/$(date +'%Y-%m-%d_%H-%M-%S').mp4"
setsid -f wf-recorder "${args[@]}" -f "$file" >/dev/null 2>&1
notify-send -t 2500 "Screen recording" "Recording started — pick Screenrecord again to stop"
