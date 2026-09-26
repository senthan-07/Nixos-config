import QtQuick
import QtQuick.Shapes

// Moon drawn for a given phase (0 new, 0.25 first quarter, 0.5 full, 0.75 last
// quarter). The lit part is an outer half-circle closed by the terminator,
// an ellipse whose width follows cos(phase).
Item {
    id: root

    property real phase: 0.5
    property color litColor: "#f1efe4"
    property color darkColor: Qt.rgba(1, 1, 1, 0.08)
    property color craterColor: Qt.rgba(0, 0, 0, 0.07)

    readonly property real r: Math.min(width, height) / 2
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property bool waxing: phase < 0.5
    readonly property real rx: Math.abs(Math.cos(2 * Math.PI * phase)) * r
    readonly property bool gibbous: phase > 0.25 && phase < 0.75

    implicitWidth: 48
    implicitHeight: 48

    Rectangle {
        anchors.centerIn: parent
        width: root.r * 2
        height: width
        radius: width / 2
        color: root.darkColor
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillColor: root.litColor
            // Outer limb on the lit side, then back along the terminator.
            PathSvg {
                path: {
                    const r = root.r, cx = root.cx, cy = root.cy;
                    const outer = root.waxing ? 1 : 0;
                    const inner = root.waxing ? (root.gibbous ? 1 : 0) : (root.gibbous ? 0 : 1);
                    return `M ${cx} ${cy - r} A ${r} ${r} 0 0 ${outer} ${cx} ${cy + r} `
                        + `A ${Math.max(0.01, root.rx)} ${r} 0 0 ${inner} ${cx} ${cy - r} Z`;
                }
            }
        }
    }

    // A few maria so the disc doesn't look like a plain circle.
    Repeater {
        model: [[0.30, 0.34, 0.20], [0.56, 0.24, 0.14], [0.50, 0.58, 0.24], [0.28, 0.66, 0.11]]
        Rectangle {
            required property var modelData
            x: root.cx - root.r + modelData[0] * root.r * 2
            y: root.cy - root.r + modelData[1] * root.r * 2
            width: modelData[2] * root.r * 2
            height: width
            radius: width / 2
            color: root.craterColor
        }
    }
}
