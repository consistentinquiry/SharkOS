import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Glass status bar: floating islands (workspaces left, clock right) drawn as
// silhouettes into a shared coverage field and rendered by GlassCanvas.
// The strip is taller than the visible bar so the blur falloff (and, later,
// notification fly-ins) has headroom; input is masked to the islands.
PanelWindow {
    id: win

    required property var modelData
    property QtObject theme

    screen: modelData
    anchors { top: true; left: true; right: true }
    implicitHeight: 56
    exclusiveZone: 48
    color: "transparent"
    WlrLayershell.namespace: "sharkos-shell"
    mask: Region { item: islands }

    readonly property real islandH: 38
    readonly property real islandY: (48 - islandH) / 2 + 2

    // ---- background source: wallpaper cropped to this strip, "cover" fit ----
    Item {
        id: bgView
        anchors.fill: parent
        visible: false
        clip: true
        Image {
            width: win.width
            height: win.screen.height
            source: win.theme && win.theme.wallpaper !== "" ? "file://" + win.theme.wallpaper : ""
            fillMode: Image.PreserveAspectCrop
            smooth: true
        }
    }

    // ---- coverage: island silhouettes only (no text, no icons) ----
    Item {
        id: coverage
        anchors.fill: parent
        visible: false
        Rectangle {
            x: wsContent.x - 16
            y: win.islandY
            width: wsContent.width + 32
            height: win.islandH
            radius: height / 2
            color: "white"
            antialiasing: true
        }
        Rectangle {
            x: clockContent.x - 18
            y: win.islandY
            width: clockContent.width + 36
            height: win.islandH
            radius: height / 2
            color: "white"
            antialiasing: true
        }
    }

    GlassCanvas {
        anchors.fill: parent
        coverage: coverage
        background: bgView
        tint: win.theme && win.theme.glassTint !== "" ? win.theme.glassTint : "#66101820"
    }

    // ---- content: drawn sharp, on top, never routed through the blur ----
    // Sized to the island band (not the full strip) because it doubles as the
    // input mask: the strip's padding below the exclusive zone must stay
    // click-through for the windows underneath.
    Item {
        id: islands
        x: 0
        y: win.islandY
        width: parent.width
        height: win.islandH

        Row {
            id: wsContent
            x: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Repeater {
                model: Hyprland.workspaces
                Rectangle {
                    required property var modelData
                    width: 22
                    height: 22
                    radius: 11
                    color: modelData.active ? Qt.alpha(win.theme ? win.theme.accent : "#7fd8e8", 0.85)
                                            : Qt.alpha("#ffffff", 0.18)
                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.id
                        color: parent.modelData.active ? "#101418"
                                                       : (win.theme ? win.theme.fg : "#ffffff")
                        font.pixelSize: 12
                        font.family: "JetBrainsMono Nerd Font"
                        font.bold: parent.modelData.active
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: Hyprland.dispatch("workspace " + parent.modelData.id)
                    }
                }
            }
        }

        Text {
            id: clockContent
            x: parent.width - width - 18 - 18
            anchors.verticalCenter: parent.verticalCenter
            text: "--:--"
            color: win.theme ? win.theme.fg : "#ffffff"
            font.pixelSize: 14
            font.family: "JetBrainsMono Nerd Font"

            Timer {
                interval: 10000
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: clockContent.text = Qt.formatDateTime(new Date(), "ddd d MMM  HH:mm")
            }
        }
    }
}
