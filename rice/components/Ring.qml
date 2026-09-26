import QtQuick
import QtQuick.Shapes
import qs.config

// Circular progress ring used for resource monitors and battery.
Item {
    id: root

    property real value: 0
    property real thickness: 3
    property color color: Theme.primary
    property color track: Theme.alpha(Theme.surfaceFg, 0.12)

    implicitWidth: 22
    implicitHeight: 22

    Behavior on value { Anim { duration: Motion.duration.long } }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.track
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: (root.width - root.thickness) / 2; radiusY: radiusX
                startAngle: 0; sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: (root.width - root.thickness) / 2; radiusY: radiusX
                startAngle: -90; sweepAngle: 360 * Math.max(0.001, Math.min(1, root.value))
            }
        }
    }
}
