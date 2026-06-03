#!/usr/bin/env python3
"""Minimal control-center popup for Hyprland/Waybar."""

import subprocess, json, os, signal, sys
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gtk, Gdk, GLib, GtkLayerShell

LOCK = "/tmp/control-center.lock"
CSS = """
window {
  background: transparent;
}
.backdrop {
  background: transparent;
}
.panel {
  background: rgba(0, 0, 0, 0.85);
  border: 1px solid rgba(255, 255, 255, 0.25);
  border-radius: 14px;
  padding: 12px;
}
.toggle-row {
  padding: 8px 12px;
  border-radius: 10px;
}
.toggle-row:hover {
  background: rgba(255, 255, 255, 0.08);
}
.toggle-label {
  color: rgba(255, 255, 255, 0.9);
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 13px;
}
.toggle-icon {
  color: rgba(255, 255, 255, 0.9);
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 16px;
  min-width: 24px;
}
.toggle-status {
  color: rgba(255, 255, 255, 0.4);
  font-family: "JetBrainsMono Nerd Font", monospace;
  font-size: 11px;
}
.toggle-switch {
  min-width: 40px;
  min-height: 22px;
}
.toggle-switch slider {
  min-width: 18px;
  min-height: 18px;
  border-radius: 9px;
  background: rgba(255, 255, 255, 0.8);
  margin: 2px;
}
.toggle-switch trough {
  min-width: 40px;
  min-height: 22px;
  border-radius: 11px;
  background: rgba(255, 255, 255, 0.15);
  border: 1px solid rgba(255, 255, 255, 0.2);
}
.toggle-switch:checked trough {
  background: rgba(100, 220, 140, 0.6);
  border: 1px solid rgba(100, 220, 140, 0.8);
}
.separator {
  background: rgba(255, 255, 255, 0.1);
  min-height: 1px;
  margin: 4px 8px;
}
"""


def run(cmd):
    try:
        return subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=5
        ).stdout.strip()
    except Exception:
        return ""


def get_airplane_mode():
    out = run("rfkill -J")
    try:
        devices = json.loads(out).get("rfkilldevices", json.loads(out).get("", []))
    except Exception:
        return False
    for d in devices:
        if d.get("type") in ("wlan", "bluetooth"):
            if d.get("soft") != "blocked":
                return False
    return True


def get_vpn_status():
    out = run("nordvpn status")
    connected = "Connected" in out and "Disconnected" not in out
    server = ""
    if connected:
        for line in out.splitlines():
            if "City:" in line:
                server = line.split(":", 1)[1].strip()
                break
            elif "Server:" in line:
                server = line.split(":", 1)[1].strip()
                break
    return connected, server


def get_hotspot_status():
    out = run("iwctl ap list 2>/dev/null")
    return "wlan0" in out and "started" in out.lower()


def pid_is_alive(pid):
    """Check if a PID is actually running."""
    try:
        os.kill(pid, 0)
        return True
    except (ProcessLookupError, PermissionError):
        return False


def cleanup_lock():
    try:
        os.unlink(LOCK)
    except OSError:
        pass


class ControlCenter(Gtk.Window):
    def __init__(self):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)

        # Apply CSS
        provider = Gtk.CssProvider()
        provider.load_from_data(CSS.encode())
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        # Layer shell: fullscreen transparent overlay
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_namespace(self, "control-center")
        GtkLayerShell.set_exclusive_zone(self, 0)
        # Anchor all edges = fullscreen
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.RIGHT, True)
        GtkLayerShell.set_keyboard_mode(
            self, GtkLayerShell.KeyboardMode.ON_DEMAND
        )

        self.set_decorated(False)
        self.set_app_paintable(True)

        # Transparent backdrop that catches clicks
        backdrop = Gtk.EventBox()
        backdrop.get_style_context().add_class("backdrop")
        backdrop.connect("button-press-event", self._on_backdrop_click)

        # Alignment: position the panel top-right with margins
        align = Gtk.Alignment(xalign=1.0, yalign=0.0, xscale=0.0, yscale=0.0)
        align.set_padding(52, 0, 0, 10)  # top, bottom, left, right

        # Build the panel
        panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        panel.get_style_context().add_class("panel")
        panel.set_size_request(260, -1)

        # Airplane Mode
        self.airplane_switch = self._make_toggle(
            "󰀝", "Airplane Mode", self._get_airplane_status, self._on_airplane_toggle
        )
        panel.pack_start(self.airplane_switch["row"], False, False, 0)
        panel.pack_start(self._make_sep(), False, False, 0)

        # VPN
        self.vpn_switch = self._make_toggle(
            "󰌆", "VPN", self._get_vpn_status_text, self._on_vpn_toggle
        )
        panel.pack_start(self.vpn_switch["row"], False, False, 0)
        panel.pack_start(self._make_sep(), False, False, 0)

        # Hotspot
        self.hotspot_switch = self._make_toggle(
            "󱜠", "Hotspot", self._get_hotspot_status, self._on_hotspot_toggle
        )
        panel.pack_start(self.hotspot_switch["row"], False, False, 0)

        # Nest: panel -> alignment -> backdrop -> window
        align.add(panel)
        backdrop.add(align)
        self.add(backdrop)

        self.connect("key-press-event", self._on_key)

        self._refresh_all()
        self.show_all()

        GLib.timeout_add_seconds(3, self._refresh_all)

    def _on_backdrop_click(self, widget, event):
        # Check if the click landed on the panel or the empty backdrop
        # Get panel allocation in window coordinates
        panel_widget = self.airplane_switch["row"].get_parent()
        alloc = panel_widget.get_allocation()

        # Translate event coords to panel's coordinate space
        _, px, py = panel_widget.translate_coordinates(self, 0, 0)
        panel_x = px
        panel_y = py
        panel_w = alloc.width
        panel_h = alloc.height

        if (panel_x <= event.x <= panel_x + panel_w and
                panel_y <= event.y <= panel_y + panel_h):
            return False  # Click was on the panel, propagate
        # Click was outside the panel — dismiss
        self._quit()
        return True

    def _make_sep(self):
        sep = Gtk.Separator()
        sep.get_style_context().add_class("separator")
        return sep

    def _make_toggle(self, icon, label, status_fn, toggle_fn):
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        row.get_style_context().add_class("toggle-row")

        icon_lbl = Gtk.Label(label=icon)
        icon_lbl.get_style_context().add_class("toggle-icon")
        row.pack_start(icon_lbl, False, False, 0)

        text_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        name_lbl = Gtk.Label(label=label, xalign=0)
        name_lbl.get_style_context().add_class("toggle-label")
        status_lbl = Gtk.Label(label="", xalign=0)
        status_lbl.get_style_context().add_class("toggle-status")
        text_box.pack_start(name_lbl, False, False, 0)
        text_box.pack_start(status_lbl, False, False, 0)
        row.pack_start(text_box, True, True, 0)

        switch = Gtk.Switch()
        switch.get_style_context().add_class("toggle-switch")
        switch.set_valign(Gtk.Align.CENTER)
        switch.connect("state-set", toggle_fn)
        row.pack_end(switch, False, False, 0)

        return {
            "row": row,
            "switch": switch,
            "status": status_lbl,
            "status_fn": status_fn,
        }

    def _refresh_all(self):
        for toggle in (self.airplane_switch, self.vpn_switch, self.hotspot_switch):
            active, status_text = toggle["status_fn"]()
            handler = (
                self._on_airplane_toggle
                if toggle is self.airplane_switch
                else self._on_vpn_toggle
                if toggle is self.vpn_switch
                else self._on_hotspot_toggle
            )
            toggle["switch"].handler_block_by_func(handler)
            toggle["switch"].set_active(active)
            toggle["switch"].handler_unblock_by_func(handler)
            toggle["status"].set_text(status_text)
        return True

    def _get_airplane_status(self):
        on = get_airplane_mode()
        return on, "All radios off" if on else "Off"

    def _get_vpn_status_text(self):
        connected, server = get_vpn_status()
        if connected:
            return True, f"Connected · {server}" if server else "Connected"
        return False, "Disconnected"

    def _get_hotspot_status(self):
        on = get_hotspot_status()
        return on, "Active" if on else "Off"

    def _on_airplane_toggle(self, switch, state):
        if state:
            subprocess.Popen(["rfkill", "block", "all"])
        else:
            subprocess.Popen(["rfkill", "unblock", "all"])
        GLib.timeout_add(800, self._refresh_all)

    def _on_vpn_toggle(self, switch, state):
        if state:
            subprocess.Popen(["nordvpn", "connect"])
        else:
            subprocess.Popen(["nordvpn", "disconnect"])
        GLib.timeout_add(2000, self._refresh_all)

    def _on_hotspot_toggle(self, switch, state):
        if state:
            subprocess.Popen(
                "iwctl station wlan0 disconnect 2>/dev/null; "
                "iwctl ap wlan0 start-profile hotspot 2>/dev/null || "
                "iwctl ap wlan0 start hotspot 2>/dev/null",
                shell=True,
            )
        else:
            subprocess.Popen(["iwctl", "ap", "wlan0", "stop"])
        GLib.timeout_add(1500, self._refresh_all)

    def _on_key(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self._quit()

    def _quit(self):
        cleanup_lock()
        Gtk.main_quit()


def main():
    # Toggle: if already running, kill the existing instance
    if os.path.exists(LOCK):
        try:
            pid = int(open(LOCK).read().strip())
            if pid_is_alive(pid):
                os.kill(pid, signal.SIGTERM)
                cleanup_lock()
                sys.exit(0)
            else:
                # Stale lock from a crashed process — clean up and start fresh
                cleanup_lock()
        except (ValueError, OSError):
            cleanup_lock()

    # Write lock with our PID
    with open(LOCK, "w") as f:
        f.write(str(os.getpid()))

    def _handle_term(*a):
        cleanup_lock()
        sys.exit(0)

    signal.signal(signal.SIGTERM, _handle_term)

    ControlCenter()
    Gtk.main()


if __name__ == "__main__":
    main()
