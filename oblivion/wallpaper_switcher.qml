import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

ShellRoot {
    PanelWindow {
        id: root
        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        property bool wallpaperSwitcherOpen: true
        WallpaperSwitcherPopup { barWindow: root }
    }

    component WallpaperSwitcherPopup: PopupWindow {
        id: wallpaperPopup
        required property PanelWindow barWindow

        anchor.window: barWindow
        anchor.rect.x: (barWindow.width  - implicitWidth)  / 2
        anchor.rect.y: (barWindow.height - implicitHeight) / 2

        implicitWidth:  960
        implicitHeight: 360
        visible: barWindow.wallpaperSwitcherOpen
        color: "transparent"

        property var  wallpapers:   []
        property real scrollOffset: 0
        property int  hoveredIndex: -1
        property bool loaded:       false

        readonly property real sliceW:       118
        readonly property real sliceH:       220
        readonly property real slantPx:      32
        readonly property real itemStep:     104
        readonly property int  visibleCount: 9
        readonly property real previewW:     260
        readonly property real previewH:     180

        Process {
            id: findProcess
            command: [
                "bash", "-c",
                "find \"$HOME/Pictures/Wallpapers\" \"$HOME/Pictures/wallpapers\" " +
                "-maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' " +
                "-o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null | sort"
            ]
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    var lines = text.trim().split("\n").filter(l => l.length > 0)
                    wallpaperPopup.wallpapers   = lines
                    wallpaperPopup.loaded       = true
                    wallpaperPopup.scrollOffset = 0
                }
            }
        }

        onVisibleChanged: {
            if (visible && !loaded) findProcess.running = true
            if (!visible) hoveredIndex = -1
        }

        Rectangle {
            anchors.fill: parent
            radius: 20
            color: "#d0101010"
            border.color: "#ffffff18"
            border.width: 1
        }

        Text {
            anchors.centerIn: parent
            visible: !wallpaperPopup.loaded
            text: "Loading wallpapers…"
            color: "#666666"; font.pixelSize: 14
        }

        Text {
            anchors.centerIn: parent
            visible: wallpaperPopup.loaded && wallpaperPopup.wallpapers.length === 0
            text: "No wallpapers found in ~/Pictures/Wallpapers/"
            color: "#888888"; font.pixelSize: 14
        }

        Item {
            id: carousel
            anchors.fill: parent
            anchors.margins: 20
            anchors.leftMargin: 44
            anchors.rightMargin: 44
            visible: wallpaperPopup.loaded && wallpaperPopup.wallpapers.length > 0

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: (wheel) => {
                    var dir = wheel.angleDelta.y > 0 ? -1 : 1
                    wallpaperPopup.scrollOffset = Math.max(0, Math.min(
                        wallpaperPopup.wallpapers.length - 1,
                        wallpaperPopup.scrollOffset + dir
                    ))
                }
            }

            Repeater {
                model: wallpaperPopup.wallpapers.length

                delegate: Item {
                    id: sliceRoot
                    required property int index

                    property real position: index - wallpaperPopup.scrollOffset
                    visible: Math.abs(position) < wallpaperPopup.visibleCount / 2 + 1
                    property bool isHovered: wallpaperPopup.hoveredIndex === index

                    property real currentScale: Math.max(0.55, 1.0 - Math.abs(position) * 0.14)
                    Behavior on currentScale {
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }

                    property real sw: wallpaperPopup.sliceW  * currentScale
                    property real sh: wallpaperPopup.sliceH  * currentScale
                    property real ss: wallpaperPopup.slantPx * currentScale

                    property real smoothX: carousel.width / 2 + position * wallpaperPopup.itemStep - (sw + ss) / 2
                    property real smoothY: (carousel.height - sh) / 2
                    Behavior on smoothX { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    x: smoothX
                    y: smoothY
                    width:  sw + ss
                    height: sh

                    opacity: Math.max(0.0, 1.0 - Math.abs(position) * 0.22)
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    z: isHovered ? 999 : Math.round((1.0 - Math.abs(position)) * 10)

                    HoverHandler {
                        onHoveredChanged: {
                            wallpaperPopup.hoveredIndex = hovered ? sliceRoot.index : -1
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached([
                                "awww", "img", wallpaperPopup.wallpapers[sliceRoot.index],
                                "--transition-type", "wipe",
                                "--transition-angle", "45",
                                "--transition-duration", "1"
                            ])
                            barWindow.wallpaperSwitcherOpen = false
                        }
                    }

                    // ── Parallelogram slice ───────────────────────────────
                    Canvas {
                        id: sliceCanvas
                        width:  sliceRoot.sw + sliceRoot.ss
                        height: sliceRoot.sh
                        antialiasing: true
                        opacity: sliceRoot.isHovered ? 0.0 : 1.0
                        Behavior on opacity {
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }

                        // The correct Qt6 Canvas image API:
                        // 1. Call loadImage(url) to register the image with the canvas engine
                        // 2. onImageLoaded fires when it's ready — then requestPaint()
                        // 3. In onPaint, draw via ctx.drawImage(url, ...) not a QML Image element
                        property string imgUrl: "file://" + wallpaperPopup.wallpapers[sliceRoot.index]

                        Component.onCompleted: {
                            loadImage(imgUrl)
                        }

                        onImageLoaded: {
                            requestPaint()
                        }

                        onWidthChanged:  requestPaint()
                        onHeightChanged: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var s = sliceRoot.ss

                            // Parallelogram clip path
                            ctx.beginPath()
                            ctx.moveTo(s,         0)
                            ctx.lineTo(width,     0)
                            ctx.lineTo(width - s, height)
                            ctx.lineTo(0,         height)
                            ctx.closePath()

                            ctx.save()
                            ctx.clip()

                            if (isImageLoaded(imgUrl)) {
                                // Draw image scaled to fill the slice, cropped to fit
                                // We manually compute a cover-fit rect so images are always horizontal
                                var imgAspect = 16 / 9  // assume landscape wallpapers
                                var sliceAspect = width / height
                                var drawW, drawH, drawX, drawY
                                if (imgAspect > sliceAspect) {
                                    // Image wider than slice — fit height, crop sides
                                    drawH = height
                                    drawW = height * imgAspect
                                    drawX = (width - drawW) / 2
                                    drawY = 0
                                } else {
                                    // Image taller than slice — fit width, crop top/bottom
                                    drawW = width
                                    drawH = width / imgAspect
                                    drawX = 0
                                    drawY = (height - drawH) / 2
                                }
                                ctx.drawImage(imgUrl, drawX, drawY, drawW, drawH)
                            } else {
                                ctx.fillStyle = "#1e1e1e"
                                ctx.fill()
                            }

                            ctx.restore()

                            // White border
                            ctx.beginPath()
                            ctx.moveTo(s,         0)
                            ctx.lineTo(width,     0)
                            ctx.lineTo(width - s, height)
                            ctx.lineTo(0,         height)
                            ctx.closePath()
                            ctx.strokeStyle = "rgba(255,255,255,0.9)"
                            ctx.lineWidth = 2
                            ctx.stroke()
                        }
                    }

                    // ── Hover preview rectangle ───────────────────────────
                    Item {
                        id: previewView
                        width:  wallpaperPopup.previewW
                        height: wallpaperPopup.previewH
                        x: (sliceRoot.width  - width)  / 2
                        y: (sliceRoot.height - height) / 2
                        opacity: sliceRoot.isHovered ? 1 : 0
                        scale:   sliceRoot.isHovered ? 1.15 : 0.88
                        transformOrigin: Item.Center

                        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on scale   { NumberAnimation { duration: 220; easing.type: Easing.OutBack  } }

                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            clip: true
                            color: "transparent"

                            Image {
                                anchors.fill: parent
                                source: "file://" + wallpaperPopup.wallpapers[sliceRoot.index]
                                fillMode: Image.PreserveAspectCrop
                                horizontalAlignment: Image.AlignHCenter
                                verticalAlignment:   Image.AlignVCenter
                                smooth: true
                                asynchronous: true
                            }
                        }

                        // White rectangle border
                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: "transparent"
                            border.color: "#ffffff"
                            border.width: 2
                        }

                        // Filename label
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.bottom
                            anchors.topMargin: 8
                            width: nameLabel.implicitWidth + 16
                            height: 24
                            radius: 12
                            color: "#cc101010"
                            border.color: "#ffffff20"
                            border.width: 1

                            Text {
                                id: nameLabel
                                anchors.centerIn: parent
                                text: wallpaperPopup.wallpapers[sliceRoot.index].split("/").pop()
                                color: "#dddddd"; font.pixelSize: 11
                                font.family: "Segoe UI Variable, Segoe UI, sans-serif"
                                elide: Text.ElideRight
                                width: Math.min(implicitWidth, 200)
                            }
                        }
                    }
                }
            }
        }

        // Left arrow
        Item {
            anchors.left: parent.left; anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 30; height: 30
            visible: wallpaperPopup.scrollOffset > 0 && wallpaperPopup.wallpapers.length > 0
            Rectangle { anchors.fill: parent; radius: 15; color: lah.containsMouse ? "#ffffff1a" : "#ffffff08" }
            HoverHandler { id: lah }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: wallpaperPopup.scrollOffset = Math.max(0, wallpaperPopup.scrollOffset - 1) }
            Text { anchors.centerIn: parent; text: "‹"; color: "#cccccc"; font.pixelSize: 20 }
        }

        // Right arrow
        Item {
            anchors.right: parent.right; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 30; height: 30
            visible: wallpaperPopup.scrollOffset < wallpaperPopup.wallpapers.length - 1 && wallpaperPopup.wallpapers.length > 0
            Rectangle { anchors.fill: parent; radius: 15; color: rah.containsMouse ? "#ffffff1a" : "#ffffff08" }
            HoverHandler { id: rah }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: wallpaperPopup.scrollOffset = Math.min(wallpaperPopup.wallpapers.length - 1, wallpaperPopup.scrollOffset + 1) }
            Text { anchors.centerIn: parent; text: "›"; color: "#cccccc"; font.pixelSize: 20 }
        }
    }
}
