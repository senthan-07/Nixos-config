import QtQuick
import QtQuick.Shapes
import qs.config
import qs.components

// Scalloped "cookie" outline in the style of the M3 expressive shape set.
// The contour is r(θ) = R · (1 − depth · (1 − |cos(nθ/2)|^puff)), which gives
// round lobes with tucked valleys; `sides` = 0 draws a circle. `depth`
// animates, so metric tiles can morph between calm and spiky.
Item {
    id: root

    property int sides: 12
    property real depth: 0.09
    property real puff: 0.6
    property color color: Theme.primaryContainer
    property color strokeColor: "transparent"
    property real strokeWidth: 0
    property int segments: Math.max(96, sides * 16)

    readonly property var points: {
        const cx = width / 2, cy = height / 2;
        const R = Math.max(0, Math.min(width, height) / 2 - strokeWidth / 2);
        const out = [];
        const n = Math.max(0, sides);
        const d = n > 0 ? Math.max(0, Math.min(0.5, depth)) : 0;
        for (let i = 0; i <= segments; i++) {
            const t = i / segments * Math.PI * 2;
            const lobe = Math.pow(Math.abs(Math.cos(n * t / 2)), puff);
            const r = R * (1 - d * (1 - lobe));
            out.push(Qt.point(cx + r * Math.cos(t - Math.PI / 2), cy + r * Math.sin(t - Math.PI / 2)));
        }
        return out;
    }

    Behavior on color { ColorAnim {} }
    Behavior on depth { Anim { duration: Motion.duration.long; easing.bezierCurve: Motion.curve.springDefault } }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.color
            strokeColor: root.strokeColor
            strokeWidth: root.strokeWidth
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: root.points }
        }
    }
}
