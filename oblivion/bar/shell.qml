pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Io

ShellRoot {
    // ── Shared state ──────────────────────────────────────────────────────────
    property bool volOsdOpen:    false
    onVolOsdOpenChanged: { console.log("[SHELL] volOsdOpen =", volOsdOpen) }
    property bool brightOsdOpen: false

    property real volValue: {
        var sink = Pipewire.defaultAudioSink
        if (!sink || !sink.audio || isNaN(sink.audio.volume)) return 0
        return sink.audio.volume
    }

    property int brightRaw: 0
    property int brightMax: 255
    property int brightPct: brightMax > 0 ? Math.round((brightRaw / brightMax) * 100) : 0

    // OSD auto-dismiss timers
    Timer {
        id: volOsdTimer
        interval: 2000
        onTriggered: shell.volOsdOpen = false
    }
    Timer {
        id: brightOsdTimer
        interval: 2000
        onTriggered: shell.brightOsdOpen = false
    }

    function showVolOsd()    { console.log("[SHELL] showVolOsd called"); brightOsdTimer.stop(); shell.brightOsdOpen = false; shell.volOsdOpen = true;    volOsdTimer.restart() }
    function showBrightOsd() { volOsdTimer.stop();    shell.volOsdOpen = false;    shell.brightOsdOpen = true; brightOsdTimer.restart() }

    Process {
        id: getBrightness
        command: ["bash", "-c", "echo $(cat /sys/class/backlight/*/brightness | head -1):$(cat /sys/class/backlight/*/max_brightness | head -1)"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(":")
                if (parts.length === 2) {
                    shell.brightRaw = parseInt(parts[0]) || 0
                    shell.brightMax = parseInt(parts[1]) || 255
                }
            }
        }
    }
    Timer { interval: 2000; running: true; repeat: true; onTriggered: getBrightness.running = true }

    id: shell

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    // ── Main panel window ─────────────────────────────────────────────────────
    PanelWindow {
        id: bar

        property color mColor: "#0f0f0f"
        property color borderColor: "#252525"
        property int topBarHeight: 48
        property int sideBarWidth: 10
        property int cornerRad: 28

        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        anchors { left: true; top: true; right: true; bottom: true }

        // ── Top Bar ──────────────────────────────────────────────────────────
        Rectangle {
            width: parent.width
            height: bar.topBarHeight
            color: bar.mColor

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: bar.sideBarWidth + 14
                anchors.rightMargin: bar.sideBarWidth + 14
                spacing: 0

                // ── LEFT ─────────────────────────────────────────────────────
                RowLayout {
                    spacing: 8; Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        implicitWidth: 28; implicitHeight: 28; radius: 6
                        color: launchArea.containsMouse ? "#1e1e1e" : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text { anchors.centerIn: parent; text: "󰣇"; color: "#e8e8e8"; font.pixelSize: 15 }
                        MouseArea { id: launchArea; anchors.fill: parent; hoverEnabled: true }
                    }

                    Rectangle { implicitWidth: 1; implicitHeight: 16; color: bar.borderColor }

                    // Workspace indicator
                    Item {
                        implicitHeight: 22; implicitWidth: 10 * 22 - 8
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            id: trail
                            y: 4; implicitHeight: 14; radius: 7
                            color: "#e8e8e8"; opacity: 0.2; z: 5
                            property int activeIndex: (Hyprland.focusedWorkspace?.id ?? 1) - 1
                            property int prevIndex: activeIndex
                            x: Math.min(activeIndex, prevIndex) * 22
                            implicitWidth: (Math.abs(activeIndex - prevIndex) + 1) * 22 - 8
                            Behavior on x            { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                            Behavior on implicitWidth { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                            onActiveIndexChanged: retract.restart()
                            Timer { id: retract; interval: 260; onTriggered: trail.prevIndex = trail.activeIndex }
                        }

                        Rectangle {
                            id: wsSlider
                            implicitWidth: 14; implicitHeight: 14; radius: 7
                            color: "transparent"; border.color: "#e8e8e8"; border.width: 2
                            y: 4; z: 10
                            property int activeIndex: (Hyprland.focusedWorkspace?.id ?? 1) - 1
                            x: activeIndex * 22
                            Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                        }

                        Repeater {
                            model: 10
                            Rectangle {
                                required property int index
                                property int wsNum: index + 1
                                property bool isOccupied: {
                                    for (var i = 0; i < Hyprland.workspaces.length; i++) {
                                        if (Hyprland.workspaces[i].id === wsNum &&
                                            Hyprland.workspaces[i].windowCount > 0) return true
                                    }
                                    return false
                                }
                                x: index * 22; y: 4
                                implicitWidth: 14; implicitHeight: 14; radius: 7
                                color: isOccupied ? "#3a3a3a" : "#222222"
                                Behavior on color { ColorAnimation { duration: 100 } }
                                MouseArea { anchors.fill: parent; onClicked: Hyprland.dispatch("workspace " + parent.wsNum) }
                            }
                        }
                    }
                }

                // ── CENTER: Clock ─────────────────────────────────────────────
                Item {
                    Layout.fillWidth: true
                    Text {
                        id: clockText
                        anchors.centerIn: parent
                        text: Qt.formatDateTime(new Date(), "hh:mm:ss AP")
                        font.pixelSize: 13; font.family: "monospace"
                        font.letterSpacing: 1.5; color: "#e8e8e8"
                        Timer {
                            interval: 1000; running: true; repeat: true
                            onTriggered: clockText.text = Qt.formatDateTime(new Date(), "hh:mm:ss AP")
                        }
                    }
                }

                // ── RIGHT: Pills ──────────────────────────────────────────────
                RowLayout {
                    spacing: 2; Layout.alignment: Qt.AlignVCenter

                    // Volume
                    ControlPill {
                        id: volPill
                        icon: {
                            var sink = Pipewire.defaultAudioSink
                            if (!sink || !sink.audio) return "󰕾"
                            if (sink.audio.muted || sink.audio.volume === 0) return "󰝟"
                            if (sink.audio.volume < 0.5) return "󰖀"
                            return "󰕾"
                        }
                        valueText: Math.round(shell.volValue * 100) + "%"
                        onScrollUp:   { console.log("[VOL PILL] scrollUp"); var s = Pipewire.defaultAudioSink; if (s?.audio) s.audio.volume = Math.min(1.0, s.audio.volume + 0.05); shell.showVolOsd() }
                        onScrollDown: { console.log("[VOL PILL] scrollDown"); var s = Pipewire.defaultAudioSink; if (s?.audio) s.audio.volume = Math.max(0.0, s.audio.volume - 0.05); shell.showVolOsd() }
                        onClicked:    { console.log("[VOL PILL] onClicked"); shell.showVolOsd() }
                    }

                    // Brightness
                    ControlPill {
                        id: brightPill
                        icon: "󰃞"
                        valueText: shell.brightPct + "%"
                        onScrollUp:   { Quickshell.execDetached(["brightnessctl", "set", "5%+"]); getBrightness.running = true; shell.showBrightOsd() }
                        onScrollDown: { Quickshell.execDetached(["brightnessctl", "set", "5%-"]); getBrightness.running = true; shell.showBrightOsd() }
                        onClicked:    shell.showBrightOsd()
                    }

                    // Wifi
                    ControlPill {
                        id: wifiPill
                        icon: wifiConnected ? "󰤨" : "󰤭"; valueText: wifiName
                        property string wifiName: "—"
                        property bool wifiConnected: wifiName !== "—" && wifiName !== ""
                        Process {
                            id: getWifi; command: ["bash", "-c", "iwgetid -r 2>/dev/null"]; running: true
                            stdout: StdioCollector { onStreamFinished: wifiPill.wifiName = text.trim() || "—" }
                        }
                        Timer { interval: 8000; running: true; repeat: true; onTriggered: getWifi.running = true }
                    }

                    // Bluetooth
                    ControlPill {
                        id: btPill
                        icon: btOn ? "󰂯" : "󰂲"; valueText: btOn ? "on" : "off"
                        property bool btOn: false
                        Process {
                            id: getBt
                            command: ["bash", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo on || echo off"]
                            running: true
                            stdout: StdioCollector { onStreamFinished: btPill.btOn = text.trim() === "on" }
                        }
                        Timer { interval: 5000; running: true; repeat: true; onTriggered: getBt.running = true }
                        onClicked: { Quickshell.execDetached(["bluetoothctl", "power", btPill.btOn ? "off" : "on"]); getBt.running = true }
                    }
                }
            }
        }

        // ── Sidebars + bottom ─────────────────────────────────────────────────
        Rectangle { width: bar.sideBarWidth; height: parent.height; color: bar.mColor }
        Rectangle { x: parent.width - bar.sideBarWidth; width: bar.sideBarWidth; height: parent.height; color: bar.mColor }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: bar.sideBarWidth; color: bar.mColor }

        // ── Corners ───────────────────────────────────────────────────────────
        Corner { x: bar.sideBarWidth;                                y: bar.topBarHeight;                               rotation: 0   }
        Corner { x: parent.width - (bar.cornerRad + bar.sideBarWidth); y: bar.topBarHeight;                             rotation: 90  }
        Corner { x: bar.sideBarWidth;                                y: parent.height - (bar.cornerRad + bar.sideBarWidth); rotation: -90 }
        Corner { x: parent.width - (bar.cornerRad + bar.sideBarWidth); y: parent.height - (bar.cornerRad + bar.sideBarWidth); rotation: 180 }

        component ControlPill: Rectangle {
            property string icon: ""; property string valueText: ""
            signal scrollUp; signal scrollDown; signal clicked
            implicitHeight: 28; implicitWidth: pillRow.implicitWidth + 16; radius: 6
            color: pillMouse.containsMouse ? "#1e1e1e" : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }

            Component.onCompleted: console.log("[PILL] Created at", x, y, "size", width, "x", height)
            RowLayout {
                id: pillRow; anchors.centerIn: parent; spacing: 5
                Text { text: icon;      font.pixelSize: 13; color: "#666666" }
                Text { text: valueText; font.pixelSize: 11; font.family: "monospace"; font.letterSpacing: 0.5; color: "#e8e8e8" }
            }
            MouseArea {
                id: pillMouse; anchors.fill: parent; hoverEnabled: true
                onClicked: { console.log("[MOUSE AREA] clicked"); parent.clicked() }
                onEntered: console.log("[MOUSE AREA] entered")
                onWheel: (w) => w.angleDelta.y > 0 ? parent.scrollUp() : parent.scrollDown()
            }
        }

        component Corner: Shape {
            id: corner
            preferredRendererType: Shape.CurveRenderer
            property real radius: bar.cornerRad
            width: radius; height: radius
            layer.enabled: true; layer.samples: 4
            ShapePath {
                strokeWidth: 0; strokeColor: "transparent"; fillColor: bar.mColor
                startX: corner.radius; startY: 0
                PathArc {
                    relativeX: -corner.radius; relativeY: corner.radius
                    radiusX: corner.radius; radiusY: corner.radius
                    direction: PathArc.Counterclockwise
                }
                PathLine { relativeX: 0;             relativeY: -corner.radius }
                PathLine { relativeX: corner.radius; relativeY: 0             }
            }
        }

        // ── Volume OSD (test: plain black box) ────────────────────────────
        PopupWindow {
            id: volOsd
            anchor.window: bar
            anchor.rect.x: 100
            anchor.rect.y: bar.topBarHeight + 10
            anchor.rect.width: 100
            anchor.rect.height: 100
            implicitWidth: 100
            implicitHeight: 100
            visible: shell.volOsdOpen
            onVisibleChanged: { console.log("[VOL OSD] visible =", visible) }
            color: "#000000"
        }

        // ── Brightness OSD ────────────────────────────────────────────────
        PopupWindow {
            id: brightOsd
            anchor.window: bar
            implicitWidth: 200
            implicitHeight: 72
            visible: shell.brightOsdOpen
            color: "transparent"
   //         onAnchoring: {
   //            anchor.rect.x = brightPill.x
   //             anchor.rect.y = brightPill.y + brightPill.height + 6
   //         }

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: "#0f0f0f"
                border.color: "#252525"; border.width: 1

                Column {
                    anchors.fill: parent; anchors.margins: 14; spacing: 10

                    RowLayout {
                        width: parent.width; spacing: 6
                        Text { text: "󰃞"; color: "#666666"; font.pixelSize: 12 }
                        Text { text: "Brightness"; color: "#888888"; font.pixelSize: 11; font.family: "monospace" }
                        Item { Layout.fillWidth: true }
                        Text { text: shell.brightPct + "%"; color: "#e8e8e8"; font.pixelSize: 11; font.family: "monospace" }
                    }

                    Item {
                        width: parent.width; height: 20

                        Rectangle {
                            id: brightTrack
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width; height: 2; radius: 1; color: "#2a2a2a"

                            Rectangle {
                                width: shell.brightMax > 0 ? (shell.brightRaw / shell.brightMax) * parent.width : 0
                                height: parent.height; radius: 1; color: "#e8e8e8"
                                Behavior on width { NumberAnimation { duration: 60 } }
                            }
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 12; height: 12; radius: 6
                            color: "#ffffff"; border.color: "#333"; border.width: 1
                            x: shell.brightMax > 0 ? (shell.brightRaw / shell.brightMax) * (brightTrack.width - width) : 0
                            Behavior on x { NumberAnimation { duration: 60 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPressed:         (m) => setBright(m.x)
                            onPositionChanged: (m) => setBright(m.x)
                            function setBright(mx) {
                                var pct = Math.max(1, Math.min(100, Math.round((mx / brightTrack.width) * 100)))
                                Quickshell.execDetached(["brightnessctl", "set", pct + "%"])
                                getBrightness.running = true
                                brightOsdTimer.restart()
                            }
                        }
                    }
                }
            }
        }

        Scope {
            PanelWindow { anchors.top: true;    implicitHeight: bar.topBarHeight }
            PanelWindow { anchors.left: true;   implicitWidth:  bar.sideBarWidth }
            PanelWindow { anchors.right: true;  implicitWidth:  bar.sideBarWidth }
            PanelWindow { anchors.bottom: true; implicitHeight: bar.sideBarWidth }
        }
    }
}
