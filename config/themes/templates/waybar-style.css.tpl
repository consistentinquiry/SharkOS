* {
  font-family: "JetBrainsMono Nerd Font", sans-serif;
  font-size: 13px;
  border: none;
  border-radius: 0;
  min-height: 0;
}

window#waybar {
  background: transparent;
}

.modules-left, .modules-center, .modules-right {
  background: {{WINDOW_BG_SOLID}};
  border: 1px solid {{BORDER_CSS}};
  border-radius: {{RADIUS_BAR}};
  margin: 6px 4px;
  padding: 0 6px;
}

#workspaces {
  padding: 0 2px;
}

#workspaces button {
  padding: 3px 10px;
  margin: 4px 2px;
  color: {{FG_DIM}};
  background: transparent;
  border-radius: {{RADIUS_BTN}};
  min-width: 28px;
}

#workspaces button:hover {
  background: {{OVERLAY_HOVER}};
  color: {{FG_SOFT}};
}

#workspaces button.active {
  background: {{ACCENT_BG}};
  color: {{FG_COLOR}};
  font-weight: bold;
  border: 1px solid {{BORDER_CSS_STRONG}};
}

#workspaces button.urgent {
  background: {{ERROR_BG_SOFT}};
  color: {{ERROR_BG}};
}

#clock {
  border-radius: {{RADIUS_CLOCK}};
  font-size: 13px;
  color: {{FG_RGBA}};
  padding: 0 8px;
}

#custom-media {
  color: {{FG_RGBA}};
  padding: 0 10px;
}

/* Update indicator: only rendered when an update is available (the module is
   empty otherwise). Accent-coloured with a slow pulse to draw the eye. */
#custom-update {
  color: {{ACCENT_BG}};
  padding: 0 10px;
  margin: 4px 1px;
  border-radius: {{RADIUS_BTN}};
  animation: update-pulse 2s ease-in-out infinite;
}

#custom-update:hover {
  background: {{OVERLAY_SOFT}};
}

@keyframes update-pulse {
  0%   { opacity: 1; }
  50%  { opacity: 0.4; }
  100% { opacity: 1; }
}

#pulseaudio, #network, #battery, #custom-clipboard, #custom-menu {
  padding: 0 10px;
  color: {{FG_RGBA}};
  margin: 4px 1px;
  border-radius: {{RADIUS_BTN}};
}

#pulseaudio:hover, #network:hover, #battery:hover, #custom-clipboard:hover, #custom-menu:hover {
  color: {{FG_RGBA}};
  background: {{OVERLAY_SOFT}};
}

#pulseaudio.muted {
  color: {{FG_MUTED}};
}

#network.disconnected {
  color: {{ERROR_RGBA}};
}

/* === Battery animations === */

@keyframes plug-in-flash {
  0%   { color: {{FG_SOFT2}}; }
  25%  { color: {{SUCCESS_BRIGHT}}; }
  60%  { color: {{SUCCESS}}; }
  100% { color: {{SUCCESS}}; }
}

@keyframes charging-pulse {
  0%   { color: {{SUCCESS}}; }
  50%  { color: {{SUCCESS_BRIGHT}}; }
  100% { color: {{SUCCESS}}; }
}

@keyframes warning-pulse {
  0%   { color: {{WARN}}; }
  50%  { color: {{WARN_BRIGHT}}; }
  100% { color: {{WARN}}; }
}

@keyframes critical-pulse {
  0%   { color: {{CRIT}}; }
  50%  { color: {{CRIT_BRIGHT}}; }
  100% { color: {{CRIT}}; }
}

#battery.charging {
  animation:
    plug-in-flash  0.5s ease-out         1,
    charging-pulse 2.5s ease-in-out 0.5s infinite;
}

#battery.plugged {
  color: {{SUCCESS_DIM}};
}

#battery.warning:not(.charging) {
  animation: warning-pulse 1.8s ease-in-out infinite;
}

#battery.critical:not(.charging) {
  animation: critical-pulse 0.9s ease-in-out infinite;
}
