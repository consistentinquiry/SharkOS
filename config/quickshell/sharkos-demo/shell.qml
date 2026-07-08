// Metaball / glass-material test bench (milestones M1+M2).
// Run inside the VM: quickshell -c sharkos-demo
// Drag the two blobs toward the top bar or each other and watch the necks
// form and break. Uses the same GlassCanvas + shaders as the real shell.
import QtQuick
import Quickshell
import "../sharkos" as Shark

ShellRoot {
    Shark.Theme { id: themeData }

    FloatingWindow {
        id: win
        title: "SharkOS liquid glass demo"
        implicitWidth: 960
        implicitHeight: 540
        color: "#101014"

        // Stand-in for the desktop behind the shell.
        Item {
            id: bgView
            anchors.fill: parent
            visible: false
            Rectangle { anchors.fill: parent; color: "#23262e" }
            Image {
                anchors.fill: parent
                source: themeData.wallpaper !== "" ? "file://" + themeData.wallpaper : ""
                fillMode: Image.PreserveAspectCrop
                smooth: true
            }
        }

        // Invisible-but-interactive drag proxies; the glass render *is* the
        // visual feedback, so these draw nothing themselves.
        Item {
            id: blobA
            x: 200; y: 260; width: 120; height: 120
            Rectangle { anchors.fill: parent; radius: width / 2; color: "transparent" }
            DragHandler {}
        }
        Item {
            id: blobB
            x: 500; y: 300; width: 90; height: 90
            Rectangle { anchors.fill: parent; radius: width / 2; color: "transparent" }
            DragHandler {}
        }

        // Silhouettes only — a fake "bar" plus the two draggable blobs.
        Item {
            id: coverage
            anchors.fill: parent
            visible: false
            Rectangle {
                x: 24; y: 24
                width: parent.width - 48; height: 44
                radius: 22
                color: "white"
                antialiasing: true
            }
            Rectangle {
                x: blobA.x; y: blobA.y; width: blobA.width; height: blobA.height
                radius: width / 2; color: "white"; antialiasing: true
            }
            Rectangle {
                x: blobB.x; y: blobB.y; width: blobB.width; height: blobB.height
                radius: width / 2; color: "white"; antialiasing: true
            }
        }

        Shark.GlassCanvas {
            anchors.fill: parent
            coverage: coverage
            background: bgView
            tint: themeData.glassTint !== "" ? themeData.glassTint : "#66101820"
            // Longer reach than the bar so the merge is easy to see while dragging.
            blurStep: 2.2
        }

        Text {
            x: 36; y: 36
            text: "drag the blobs — they should merge like water droplets"
            color: "#ffffff"
            font.pixelSize: 14
            font.family: "JetBrainsMono Nerd Font"
        }
    }
}
