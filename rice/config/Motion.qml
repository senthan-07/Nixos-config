pragma Singleton

import QtQuick
import Quickshell

// Material 3 motion tokens. Curves are cubic-bezier control points in the
// format BezierSpline expects ([x1, y1, x2, y2, 1, 1]).
Singleton {
    readonly property QtObject curve: QtObject {
        readonly property var standard: [0.2, 0, 0, 1, 1, 1]
        readonly property var standardAccel: [0.3, 0, 1, 1, 1, 1]
        readonly property var standardDecel: [0, 0, 0, 1, 1, 1]
        readonly property var emphasized: [0.05, 0, 0.133, 0.06, 0.167, 0.4, 0.208, 0.82, 0.25, 1, 1, 1]
        readonly property var emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property var emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
        readonly property var springFast: [0.42, 1.67, 0.21, 0.9, 1, 1]
        readonly property var springDefault: [0.38, 1.21, 0.22, 1, 1, 1]
    }

    // Settings > General > Animations: 0 off, 0.5 fast, 1 normal, 1.5 relaxed.
    readonly property real scale: Settings.data.animationScale

    readonly property QtObject duration: QtObject {
        readonly property int tiny: Math.round(100 * scale)
        readonly property int short: Math.round(200 * scale)
        readonly property int medium: Math.round(350 * scale)
        readonly property int long: Math.round(500 * scale)
    }
}
