import QtQuick
import QtQuick.Shapes
import qs.config
import qs.components

// Animated liquid surface filling its parent from the bottom up to `level`.
// Two sine layers drift in opposite directions; the paths are built once per
// size and only translated, so the animation is cheap. `running: false`
// freezes the surface (the level itself still animates).
Item {
    id: root

    property real level: 0
    property color color: Theme.primary
    property color backColor: Theme.alpha(color, 0.45)
    property bool running: true
    property real amplitude: Math.max(2, Math.min(7, height * 0.035))
    property real wavelength: Math.max(40, width * 0.6)

    property real shown: Math.max(0, Math.min(1, level))
    Behavior on shown { Anim { duration: Motion.duration.long * 2; easing.bezierCurve: Motion.curve.emphasizedDecel } }

    clip: true

    // Top edge of the liquid body, in local coordinates.
    readonly property real surfaceY: height * (1 - shown)

    function wavePath(w, h, amp, len) {
        // Starts at x = 0, spans w + 2·len so a shift by one wavelength loops.
        const total = w + len * 2;
        const half = len / 2;
        let d = `M 0 ${amp}`;
        for (let x = 0; x < total; x += len) {
            d += ` Q ${x + half / 2} ${-amp} ${x + half} ${amp}`;
            d += ` Q ${x + half * 1.5} ${amp * 3} ${x + len} ${amp}`;
        }
        return d + ` L ${total} ${h + amp * 2} L 0 ${h + amp * 2} Z`;
    }

    component Wave: Shape {
        id: wave
        property color fill
        property real phase: 0
        property bool reverse: false
        property int period: 2600

        width: root.width + root.wavelength * 2
        height: root.height + root.amplitude * 4
        x: -root.wavelength * (reverse ? 1 - phase : phase)
        y: root.surfaceY - root.amplitude * 2
        visible: root.shown > 0.001
        preferredRendererType: Shape.CurveRenderer

        NumberAnimation on phase {
            from: 0; to: 1
            duration: wave.period
            loops: Animation.Infinite
            running: root.running && root.visible && root.shown > 0.001
        }

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: wave.fill
            PathSvg { path: root.wavePath(root.width, root.height, root.amplitude, root.wavelength) }
        }
    }

    Wave { fill: root.backColor; reverse: true; period: 3400; y: root.surfaceY - root.amplitude * 3 }
    Wave { fill: root.color; period: 2600 }
}
