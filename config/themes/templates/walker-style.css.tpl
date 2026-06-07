@define-color window_bg_color {{WINDOW_BG}};
@define-color accent_bg_color {{ACCENT_BG}};
@define-color theme_fg_color {{FG_COLOR}};
@define-color border_color {{BORDER_CSS}};
@define-color error_bg_color {{ERROR_BG}};
@define-color error_fg_color {{ERROR_FG}};

* {
  all: unset;
  font-family: "JetBrainsMono Nerd Font", sans-serif;
}

popover {
  background: lighter(@window_bg_color);
  border: 1px solid @border_color;
  border-radius: {{RADIUS_POPOVER}};
  border-color: {{BORDER_CSS}};
  padding: 10px;
}

.normal-icons {
  -gtk-icon-size: 16px;
}

.large-icons {
  -gtk-icon-size: 32px;
}

scrollbar {
  opacity: 0;
}

.box-wrapper {
  box-shadow:
    0 19px 38px rgba(0, 0, 0, 0.5),
    0 15px 12px rgba(0, 0, 0, 0.35);
  background: @window_bg_color;
  padding: 20px;
  border-radius: {{RADIUS_WRAPPER}};
  border: 2px solid {{BORDER_CSS_STRONG}};
}

.preview-box,
.elephant-hint,
.placeholder {
  color: @theme_fg_color;
  opacity: 0.5;
}

.box {
}

.search-container {
  border-radius: {{RADIUS_MD}};
}

.input placeholder {
  opacity: 0.4;
}

.input selection {
  background: {{ACCENT_SEL}};
}

.input {
  caret-color: @theme_fg_color;
  background: {{OVERLAY_SOFT}};
  padding: 10px;
  color: @theme_fg_color;
  border: 1px solid @border_color;
  border-radius: {{RADIUS_MD}};
}

.input:focus,
.input:active {
  border-color: {{BORDER_FOCUS}};
}

.content-container {
}

.scroll {
}

.list {
  color: @theme_fg_color;
}

.item-box {
  border-radius: {{RADIUS_MD}};
  padding: 10px;
  /* Transparent border so the selected row (which gains a coloured border)
     doesn't grow 2px taller than the rest. */
  border: 1px solid transparent;
}

.item-quick-activation {
  background: {{OVERLAY_HOVER}};
  border-radius: {{RADIUS_QUICK}};
  padding: 10px;
}

child:selected .item-box,
row:selected .item-box {
  background: {{ACCENT_BG}};
  border: 1px solid @border_color;
}

.item-text-box {
}

.item-subtext {
  font-size: 12px;
  opacity: 0.45;
}

.providerlist .item-subtext {
  font-size: unset;
  opacity: 0.75;
}

.item-image-text {
  font-size: 28px;
}

.preview {
  border: 1px solid @border_color;
  border-radius: {{RADIUS_MD}};
  color: @theme_fg_color;
}

.calc .item-text {
  font-size: 24px;
}

.symbols .item-image {
  font-size: 24px;
}

.todo.done .item-text-box {
  opacity: 0.25;
}

.todo.urgent {
  font-size: 24px;
}

.todo.active {
  font-weight: bold;
}

.bluetooth.disconnected {
  opacity: 0.5;
}

.preview .large-icons {
  -gtk-icon-size: 64px;
}

.keybinds {
  padding-top: 10px;
  border-top: 1px solid {{HAIRLINE}};
  font-size: 12px;
  color: @theme_fg_color;
}

.keybind-button {
  opacity: 0.5;
}

.keybind-button:hover {
  opacity: 0.75;
}

.keybind-bind {
  text-transform: lowercase;
  opacity: 0.35;
}

.keybind-label {
  padding: 2px 4px;
  border-radius: {{RADIUS_KEYBIND}};
  border: 1px solid {{BORDER_CSS}};
}

.error {
  padding: 10px;
  background: @error_bg_color;
  color: @error_fg_color;
  border-radius: {{RADIUS_MD}};
}

:not(.calc).current {
  font-style: italic;
}

.preview-content.archlinuxpkgs,
.preview-content.dnfpackages {
  font-family: monospace;
}
