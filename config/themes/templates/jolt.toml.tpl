# sharkOS jolt theme — generated from the active palette by apply-theme.sh.
# Do not edit by hand; edit config/themes/templates/jolt.toml.tpl and re-apply
# the theme. Both [dark] and [light] hold the same sharkOS palette so jolt
# matches the system theme regardless of its light/dark auto-detection.
#
# Colour sources (from the theme's theme.conf):
#   background  = terminal bg          foreground = terminal fg
#   accent      = theme accent         border/muted = ANSI bright-black
#   battery/impact/status = ANSI red/green/yellow ramp

[dark]
background = "#{{COLOR_BG}}"
foreground = "{{FG_COLOR}}"
border = "#{{COLOR_8}}"
accent = "{{ACCENT_HEX}}"
muted = "#{{COLOR_8}}"

battery_high = "#{{COLOR_2}}"
battery_medium = "#{{COLOR_3}}"
battery_low = "#{{COLOR_1}}"
battery_charging = "{{ACCENT_HEX}}"

impact_low = "#{{COLOR_2}}"
impact_moderate = "#{{COLOR_3}}"
impact_elevated = "#{{COLOR_11}}"
impact_high = "#{{COLOR_1}}"

graph_line = "{{ACCENT_HEX}}"
graph_fill = "#{{COLOR_BG}}"
selection = "{{ACCENT_HEX}}"
error = "#{{COLOR_1}}"
warning = "#{{COLOR_3}}"
success = "#{{COLOR_2}}"

[light]
background = "#{{COLOR_BG}}"
foreground = "{{FG_COLOR}}"
border = "#{{COLOR_8}}"
accent = "{{ACCENT_HEX}}"
muted = "#{{COLOR_8}}"

battery_high = "#{{COLOR_2}}"
battery_medium = "#{{COLOR_3}}"
battery_low = "#{{COLOR_1}}"
battery_charging = "{{ACCENT_HEX}}"

impact_low = "#{{COLOR_2}}"
impact_moderate = "#{{COLOR_3}}"
impact_elevated = "#{{COLOR_11}}"
impact_high = "#{{COLOR_1}}"

graph_line = "{{ACCENT_HEX}}"
graph_fill = "#{{COLOR_BG}}"
selection = "{{ACCENT_HEX}}"
error = "#{{COLOR_1}}"
warning = "#{{COLOR_3}}"
success = "#{{COLOR_2}}"
