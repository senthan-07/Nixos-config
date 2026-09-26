import QtQuick
import QtQuick.Shapes
import qs.config

// Open arc gauge (default 270°, gap at the bottom) with a knob at the tip.
Item {
    id: root

    property real value: 0              // 0..1
    property real thickness: 10
    property color color: Theme.primary
    property color track: Theme.alpha(color, 0.18)
    property real startAngle: 135
    property real sweep: 270
    property bool knob: true

    readonly property real clamped: Math.max(0, Math.min(1, value))
    readonly property real radius: Math.min(width, height) / 2 - thickness / 2 - 2
    readonly property real tipAngle: (startAngle + sweep * clamped) * Math.PI / 180

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
                radiusX: root.radius; radiusY: root.radius
                startAngle: root.startAngle; sweepAngle: root.sweep
            }
        }

        ShapePath {
            strokeColor: root.clamped > 0.002 ? root.color : "transparent"
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2
                radiusX: root.radius; radiusY: root.radius
                startAngle: root.startAngle; sweepAngle: Math.max(0.1, root.sweep * root.clamped)
            }
        }
    }

    Rectangle {
        visible: root.knob
        width: root.thickness + 6
        height: width
        radius: width / 2
        x: root.width / 2 + Math.cos(root.tipAngle) * root.radius - width / 2
        y: root.height / 2 + Math.sin(root.tipAngle) * root.radius - height / 2
        color: Theme.surfaceContainer
        border.width: 3
        border.color: root.color
    }
}
