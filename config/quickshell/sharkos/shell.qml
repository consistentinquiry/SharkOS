// SharkOS liquid-glass shell (beta) — activated by themes with SHELL_KIND="quickshell".
// Run: quickshell -c sharkos
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    Theme { id: themeData }

    // Demo-only mode: show just the test bench, no bar (for a second instance
    // alongside the real shell). Quickshell blocks imports from outside the
    // config folder, so the demo lives here rather than in its own config.
    readonly property bool demoOnly: Quickshell.env("SHARKOS_DEMO") === "1"

    Variants {
        model: root.demoOnly ? [] : Quickshell.screens
        Bar { theme: themeData }
    }

    DemoWindow {
        id: demoWin
        theme: themeData
        visible: root.demoOnly
    }

    IpcHandler {
        target: "demo"
        function toggle(): void { demoWin.visible = !demoWin.visible; }
    }
}
