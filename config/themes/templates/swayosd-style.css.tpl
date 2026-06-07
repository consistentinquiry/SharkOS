window {
  background: transparent;
  padding: 12px;
}

#container {
  background: {{WINDOW_BG_SOLID}};
  border: 1px solid {{BORDER_CSS}};
  border-radius: {{RADIUS_BAR}};
  padding: 12px 20px;
  color: {{FG_COLOR}};
}

image {
  color: {{FG_SOFT2}};
  padding-right: 8px;
}

progressbar,
scale trough {
  min-height: 6px;
  min-width: 180px;
  border-radius: {{RADIUS_QUICK}};
  background: {{OVERLAY_HOVER}};
}

progressbar progress,
scale trough highlight {
  background: {{ACCENT_HEX}};
  border-radius: {{RADIUS_QUICK}};
}

label {
  font-family: "JetBrainsMono Nerd Font", sans-serif;
  font-size: 13px;
  color: {{FG_RGBA}};
}
