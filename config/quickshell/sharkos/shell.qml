// SharkOS liquid-glass shell (beta) — activated by themes with SHELL_KIND="quickshell".
// Run: quickshell -c sharkos
import QtQuick
import Quickshell

ShellRoot {
    Theme { id: themeData }

    Variants {
        model: Quickshell.screens
        Bar { theme: themeData }
    }
}
