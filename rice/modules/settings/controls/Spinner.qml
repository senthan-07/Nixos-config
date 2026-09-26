import QtQuick
import QtQuick.Shapes
import qs.config
import qs.components

// Indeterminate circular progress: an arc that grows, shrinks and rotates.
Item {
    id: root

    property real size: 32
    property real thickness: Math.max(2.5, size / 10)
    property color color: Theme.primary
    property bool running: visible

    implicitWidth: size
    implicitHeight: size

    property real sweep: 40
    property real turn: 0

    SequentialAnimation on sweep {
        running: root.running
        loops: Animation.Infinite
        NumberAnimation { from: 30; to: 270; duration: 700; easing.type: Easing.InOutCubic }
        NumberAnimation { from: 270; to: 30; duration: 700; easing.type: Easing.InOutCubic }
    }
    NumberAnimation on turn {
        running: root.running
        loops: Animation.Infinite
        from: 0; to: 360
        duration: 1100
    }

    Shape {
        anchors.fill: parent
        rotation: root.turn
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.size / 2; centerY: root.size / 2
                radiusX: (root.size - root.thickness) / 2; radiusY: radiusX
                startAngle: -90; sweepAngle: root.sweep
            }
        }
    }
}
