/* sharkOS SwayNC theme — generated from the active palette by apply-theme.sh.
   Do not edit by hand; edit config/themes/templates/swaync.css.tpl and
   re-apply the theme. */

* {
  font-family: "JetBrainsMono Nerd Font", sans-serif;
  font-size: 13px;
}

/* Semi-transparent surfaces over a Hyprland blur layerrule (namespaces
   swaync-control-center / swaync-notification-window) give the same frosted
   glass as the walker/elephant menu — keep these backgrounds translucent. */

/* ── Floating toast popups (shown briefly when a notification arrives) ── */
.floating-notifications.background .notification-row .notification-background {
  background: {{WINDOW_BG}};
  border: 1px solid {{BORDER_CSS}};
  border-radius: {{RADIUS_POPOVER}};
  margin: 6px;
}

/* ── Control center panel ── */
/* Border matches walker/elephant's .box-wrapper (2px BORDER_CSS_STRONG) for
   UI consistency across the desktop's surfaces. */
.control-center {
  background: {{WINDOW_BG}};
  border: 2px solid {{BORDER_CSS_STRONG}};
  border-radius: {{RADIUS_WRAPPER}};
  padding: 12px;
}

/* Title row + "Clear all" (dismiss all) button */
.control-center .widget-title {
  color: {{FG_RGBA}};
  margin: 4px 6px 10px 6px;
  font-size: 15px;
  font-weight: bold;
}
.control-center .widget-title > button {
  color: {{FG_RGBA}};
  background: {{OVERLAY_SOFT}};
  border: 1px solid {{BORDER_CSS}};
  border-radius: {{RADIUS_BTN}};
  padding: 4px 12px;
  font-weight: normal;
}
.control-center .widget-title > button:hover {
  background: {{ACCENT_BG}};
  border-color: {{BORDER_FOCUS}};
}

/* Do-not-disturb toggle */
.control-center .widget-dnd {
  color: {{FG_SOFT}};
  margin: 0 6px 8px 6px;
}
.control-center .widget-dnd > switch {
  background: {{OVERLAY_SOFT}};
  border: 1px solid {{BORDER_CSS}};
  border-radius: {{RADIUS_QUICK}};
}
.control-center .widget-dnd > switch:checked {
  background: {{ACCENT_BG}};
}

/* ── Notification rows ──
   SwayNC nests several frames around each notification: a group container, the
   row background, and the notification's own default border + box-shadow. Left
   alone they stack up as concentric rectangles. Flatten them all to transparent
   and paint a single clean card on .notification. */
.notification-group {
  background: transparent;
  border: none;
  box-shadow: none;
}
.notification-row {
  outline: none;
  margin: 4px 2px;
  background: transparent;
}
.notification-row .notification-background {
  background: transparent;
  border: none;
  box-shadow: none;
  padding: 0;
}
.notification-row .notification-background .notification {
  /* A solid card surface: the frosted blur shows through the panel itself,
     but each card is opaque so a stack doesn't show through into the cards
     behind it. */
  background: {{WINDOW_BG_SOLID}};
  border: none;
  box-shadow: none;
  border-radius: {{RADIUS_MD}};
  margin: 0;
  padding: 0;
}
.notification-row .notification-background .notification.critical {
  border: 1px solid {{CRIT}};
}

/* The clickable card body. Padding + radius live here so the hover
   illumination fills exactly the card, not the wider row. */
.notification-row .notification-background .notification .notification-default-action {
  margin: 0;
  padding: 10px;
  border-radius: {{RADIUS_MD}};
  background: transparent;
  outline: none;
  box-shadow: none;
}
.notification-row .notification-background .notification .notification-default-action:hover {
  background: {{OVERLAY_HOVER}};
}

/* Suppress SwayNC's full-row focus/hover highlight and the GTK focus ring —
   the highlight was wider than the card and bled toward the next notification.
   The only highlight is now the hover fill above, sized to the card. */
.notification-row,
.notification-row:focus,
.notification-row:hover,
.notification-row .notification-background .notification:focus,
.notification-row .notification-background .notification .notification-default-action:focus {
  background: transparent;
  outline: none;
  box-shadow: none;
}

/* Text */
.notification-row .summary {
  color: {{FG_COLOR}};
  font-weight: bold;
}
.notification-row .body {
  color: {{FG_SOFT}};
}
.notification-row .time {
  color: {{FG_DIM}};
}

/* Per-notification close button (dismiss one) */
.notification-row .close-button {
  color: {{FG_SOFT}};
  background: transparent;
  border: none;
  border-radius: {{RADIUS_QUICK}};
  margin: 4px;
  padding: 2px 6px;
}
.notification-row .close-button:hover {
  background: {{ERROR_BG_SOFT}};
  color: {{FG_COLOR}};
}

/* Inline action buttons (e.g. "Reply", "Open") */
.notification-action {
  color: {{FG_RGBA}};
  background: {{OVERLAY_SOFT}};
  border: 1px solid {{BORDER_CSS}};
  border-radius: {{RADIUS_BTN}};
  margin: 4px;
}
.notification-action:hover {
  background: {{ACCENT_BG}};
  border-color: {{BORDER_FOCUS}};
}

/* Empty state */
.control-center .notification-group-headers,
.blank-window {
  color: {{FG_DIM}};
  background: transparent;
}
