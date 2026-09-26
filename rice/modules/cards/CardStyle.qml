pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Shared look for the system cards: display font, colour mixing and the
// desktop grid metrics.
Singleton {
    // Inter Display ships with Inter; tighter spacing at large sizes.
    readonly property string display: "Inter Display"

    // Desktop grid: a card of span n is n * cell + (n - 1) * gap pixels.
    readonly property int cell: 80
    readonly property int gap: 16
    readonly property int pitch: cell + gap
    readonly property int edge: 24

    // services/Weather.qml is owned by another module; the weather card only
    // loads its body (which references the singleton) when the file exists.
    readonly property bool weatherAvailable: weatherProbe.loaded

    FileView {
        id: weatherProbe
        path: Quickshell.shellPath("services/Weather.qml")
        blockLoading: true
        printErrors: false
    }

    function span(n) {
        return n * cell + (n - 1) * gap;
    }

    function mix(a, b, t) {
        return Qt.rgba(a.r * (1 - t) + b.r * t, a.g * (1 - t) + b.g * t, a.b * (1 - t) + b.b * t, a.a * (1 - t) + b.a * t);
    }

    function clamp01(v) {
        return Math.max(0, Math.min(1, Number(v) || 0));
    }

    function percent(v) {
        return Math.round(clamp01(v) * 100) + "%";
    }
}
