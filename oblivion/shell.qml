import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes

ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Item {
            id: config
            property color edgeColor: "black"
            property int thickness: 20
            property int cornerRadius: 40

            // --- BARS ---
            PanelWindow {
                anchors.top: true; anchors.left: true; anchors.right: true
                implicitHeight: config.thickness
                color: config.edgeColor
            }
            PanelWindow {
                anchors.left: true; anchors.top: true; anchors.bottom: true
                implicitWidth: config.thickness
                color: config.edgeColor
            }

            // --- TOP-LEFT CORNER (CORRECTED CURVE) ---
            PanelWindow {
                anchors.top: true; anchors.left: true
                implicitWidth: config.cornerRadius + config.thickness
                implicitHeight: config.cornerRadius + config.thickness
                color: "transparent"

                Shape {
                    anchors.fill: parent
                    ShapePath {
                        fillColor: config.edgeColor
                        strokeColor: "transparent"

                        // Start at the top-left screen absolute corner
                        startX: 0; startY: 0
                        // Extend to the end of the top bar section
                        PathLine { x: config.cornerRadius + config.thickness; y: 0 }
                        // Move down to the inner edge of the top bar
                        PathLine { x: config.cornerRadius + config.thickness; y: config.thickness }

                        // Arc back towards the left bar's inner edge
                        // This creates the 'rounded' inside look
                        PathArc {
                            x: config.thickness; y: config.cornerRadius + config.thickness
                            radiusX: config.cornerRadius; radiusY: config.cornerRadius
                            direction: PathArc.Clockwise
                        }

                        // Connect to the left bar's outer edge
                        PathLine { x: 0; y: config.cornerRadius + config.thickness }
                        PathLine { x: 0; y: 0 }
                    }
                }
            }
        }
    }
}
