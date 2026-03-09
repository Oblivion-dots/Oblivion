import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Scope {
    id: root

    property string timeStr: ""
    property string dateStr: ""

    GlobalShortcut {
        appid: "quickshell"
        name: "startmenu_toggle"
        onPressed: {
            // Toggle on whichever screen has focus — just use the first barWindow
            firstBar.startMenuOpen = !firstBar.startMenuOpen
        }
    }

    Process {
        id: clockProc
        command: ["bash", "-c", "date '+%I:%M %p|%m/%d/%Y'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split("|")
                root.timeStr = parts[0] || ""
                root.dateStr = parts[1] || ""
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockProc.running = true
    }

    property var pinnedTaskbar: [
        { icon: "firefox",   label: "Firefox",  cmd: ["firefox"]  },
        { icon: "nautilus",  label: "Files",    cmd: ["nautilus"] },
        { icon: "kitty",     label: "Terminal", cmd: ["kitty"]    },
        { icon: "code-oss",  label: "VS Code",  cmd: ["code"]     },
        { icon: "discord",   label: "Discord",  cmd: ["discord"]  },
    ]

    FileView {
        id: taskbarPinsFile
        path: Qt.resolvedUrl("pinned_taskbar.json")
        watchChanges: true
        onFileChanged: reload()
        onTextChanged: {
            try {
                var parsed = JSON.parse(text)
                if (parsed.length > 0) {
                    var result = []
                    for (var i = 0; i < parsed.length; i++) {
                        result.push({ icon: parsed[i].icon, label: parsed[i].label, cmd: [parsed[i].icon] })
                    }
                    root.pinnedTaskbar = result
                }
            } catch(e) {}
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: barWindow
                required property var modelData
                screen: modelData
                property bool startMenuOpen: false

                // Expose the first bar so GlobalShortcut can reach it
                Component.onCompleted: {
                    if (!root.firstBarSet) {
                        root.firstBar = barWindow
                        root.firstBarSet = true
                    }
                }

                anchors.bottom: true
                anchors.left: true
                anchors.right: true
                implicitHeight: 48
                color: "#dd1c1c1c"
                exclusiveZone: 48

                // Top border
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: "#505050"
                }

                // Start menu
                StartMenu {
                    barWindow: barWindow
                }

                // BAR CONTENT
                Item {
                    anchors.fill: parent

                    // LEFT: Start + Search + Task View
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        // Start button
                        Rectangle {
                            width: 40; height: 40; radius: 6
                            color: startHover.containsMouse ? "#2d5fa6" : "transparent"

                            HoverHandler { id: startHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: barWindow.startMenuOpen = !barWindow.startMenuOpen
                            }

                            Item {
                                anchors.centerIn: parent
                                width: 20; height: 20
                                Rectangle { x: 0;  y: 0;  width: 9; height: 9; color: "#4cc2ff" }
                                Rectangle { x: 11; y: 0;  width: 9; height: 9; color: "#4cc2ff" }
                                Rectangle { x: 0;  y: 11; width: 9; height: 9; color: "#4cc2ff" }
                                Rectangle { x: 11; y: 11; width: 9; height: 9; color: "#4cc2ff" }
                            }
                        }

                        // Search bar
                        Rectangle {
                            width: 200; height: 36; radius: 18
                            color: searchHover.containsMouse ? "#3a3a3a" : "#2d2d2d"
                            border.color: "#555"; border.width: 1

                            HoverHandler { id: searchHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: barWindow.startMenuOpen = true
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                spacing: 8

                                Item {
                                    width: 16; height: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    Rectangle {
                                        width: 10; height: 10; radius: 5
                                        color: "transparent"
                                        border.color: "#aaa"; border.width: 2
                                    }
                                    Rectangle {
                                        width: 2; height: 6; color: "#aaa"
                                        x: 11; y: 8
                                        rotation: 135
                                        transformOrigin: Item.Center
                                    }
                                }
                                Text {
                                    text: "Search"
                                    color: "#aaa"; font.pixelSize: 13
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // Task View
                        Rectangle {
                            width: 40; height: 40; radius: 6
                            color: taskHover.containsMouse ? "#3d3d3d" : "transparent"

                            HoverHandler { id: taskHover }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor }

                            Item {
                                anchors.centerIn: parent
                                width: 20; height: 18
                                Rectangle { x: 0; y: 4; width: 13; height: 11; radius: 2; color: "transparent"; border.color: "#aaa"; border.width: 2 }
                                Rectangle { x: 6; y: 0; width: 13; height: 11; radius: 2; color: "#1c1c1c"; border.color: "#ccc"; border.width: 2 }
                            }
                        }
                    }

                    // CENTER: Pinned taskbar icons
                    Row {
                        anchors.centerIn: parent
                        spacing: 2

                        Repeater {
                            model: root.pinnedTaskbar

                            delegate: Item {
                                required property var modelData
                                width: 44; height: 48
                                property bool hovered: iconHover.containsMouse

                                HoverHandler { id: iconHover }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(modelData.cmd)
                                }

                                Rectangle {
                                    id: iconBg
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: -2
                                    width: 40; height: 40; radius: 6
                                    color: parent.hovered ? "#3d3d3d" : "transparent"
                                }

                                Text {
                                    anchors.centerIn: iconBg
                                    text: modelData.label.charAt(0).toUpperCase()
                                    color: "#666"; font.pixelSize: 16; font.bold: true
                                }

                                Image {
                                    anchors.centerIn: iconBg
                                    width: 24; height: 24
                                    source: Quickshell.iconPath(modelData.icon, true)
                                    smooth: true
                                    visible: source.toString() !== ""
                                }

                                Rectangle {
                                    anchors.bottom: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottomMargin: 6
                                    width: tipText.implicitWidth + 14
                                    height: 22; radius: 4
                                    color: "#2a2a2a"
                                    border.color: "#555"; border.width: 1
                                    visible: parent.hovered
                                    z: 100

                                    Text {
                                        id: tipText
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: "#fff"; font.pixelSize: 11
                                    }
                                }
                            }
                        }
                    }

                    // RIGHT: tray + clock + bell + show-desktop
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        Rectangle {
                            width: 28; height: 28; radius: 4
                            color: chevHover.containsMouse ? "#3d3d3d" : "transparent"
                            anchors.verticalCenter: parent.verticalCenter

                            HoverHandler { id: chevHover }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor }
                            Text { anchors.centerIn: parent; text: "^"; color: "#ccc"; font.pixelSize: 11; font.bold: true }
                        }

                        Repeater {
                            model: [
                                { icon: "audio-volume-high",        label: "Volume"  },
                                { icon: "network-transmit-receive", label: "Network" },
                                { icon: "battery",                  label: "Battery" },
                            ]

                            delegate: Item {
                                required property var modelData
                                width: 28; height: 48
                                property bool hovered: trayHover.containsMouse

                                HoverHandler { id: trayHover }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 26; height: 26; radius: 4
                                    color: parent.hovered ? "#3d3d3d" : "transparent"

                                    Text { anchors.centerIn: parent; text: modelData.label.charAt(0); color: "#888"; font.pixelSize: 11 }
                                    Image {
                                        anchors.centerIn: parent
                                        width: 16; height: 16
                                        source: Quickshell.iconPath(modelData.icon, true)
                                        smooth: true
                                        visible: source.toString() !== ""
                                    }
                                }

                                Rectangle {
                                    anchors.bottom: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottomMargin: 4
                                    width: trayTip.implicitWidth + 10
                                    height: 20; radius: 4
                                    color: "#2a2a2a"; border.color: "#555"; border.width: 1
                                    visible: parent.hovered; z: 100

                                    Text { id: trayTip; anchors.centerIn: parent; text: modelData.label; color: "#fff"; font.pixelSize: 11 }
                                }
                            }
                        }

                        Rectangle { width: 1; height: 24; color: "#505050"; anchors.verticalCenter: parent.verticalCenter }

                        Rectangle {
                            width: 80; height: 44; radius: 6
                            color: clockHover.containsMouse ? "#3d3d3d" : "transparent"
                            anchors.verticalCenter: parent.verticalCenter

                            HoverHandler { id: clockHover }
                            Column {
                                anchors.centerIn: parent; spacing: 1
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.timeStr; color: "#fff"; font.pixelSize: 12 }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.dateStr; color: "#ccc"; font.pixelSize: 11 }
                            }
                        }

                        Rectangle {
                            width: 32; height: 44; radius: 6
                            color: bellHover.containsMouse ? "#3d3d3d" : "transparent"
                            anchors.verticalCenter: parent.verticalCenter

                            HoverHandler { id: bellHover }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor }
                            Item {
                                anchors.centerIn: parent; width: 16; height: 18
                                Rectangle { x: 2; y: 3; width: 12; height: 10; radius: 5; color: "#ccc" }
                                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 12; width: 5; height: 3; radius: 2; color: "#ccc" }
                                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 0; width: 2; height: 5; color: "#ccc" }
                            }
                        }

                        Rectangle {
                            width: 5; height: 48
                            color: sdHover.containsMouse ? "#60cdff" : "#383838"
                            anchors.verticalCenter: parent.verticalCenter

                            HoverHandler { id: sdHover }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
            }
        }
    }

    property var firstBar: null
    property bool firstBarSet: false
}
