import QtQuick
import qs.config
import qs.components

// M3 expressive progress: a wavy line for the elapsed part while playing,
// flat track for the rest, with a vertical handle. Click or drag to seek.
Item {
    id: root

    property real progress: 0            // 0..1
    property bool playing: false
    property bool seekable: true
    property color color: Theme.primary
    property color track: Theme.alpha(Theme.surfaceFg, 0.16)
    property real amplitude: playing ? 3 : 0
    property real wavelength: 26
    property real phase: 0

    signal seek(real fraction)

    implicitHeight: 24
    implicitWidth: 240

    readonly property real shown: drag.pressed ? drag.live : Math.max(0, Math.min(1, progress))
    readonly property real handleX: shown * width

    Behavior on amplitude { Anim { duration: Motion.duration.long } }

    NumberAnimation on phase {
        running: root.playing && root.visible
        from: 0; to: Math.PI * 2
        duration: 1600
        loops: Animation.Infinite
    }

    onPhaseChanged: canvas.requestPaint()
    onShownChanged: canvas.requestPaint()
    onAmplitudeChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onTrackChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const mid = height / 2, gap = 6, lw = 4;
            const hx = root.handleX;
            ctx.lineCap = "round";
            ctx.lineWidth = lw;
            // remaining track
            if (hx + gap < width - lw / 2) {
                ctx.strokeStyle = String(root.track);
                ctx.beginPath();
                ctx.moveTo(Math.min(width - lw / 2, hx + gap), mid);
                ctx.lineTo(width - lw / 2, mid);
                ctx.stroke();
            }
            // elapsed wave
            const end = hx - gap;
            if (end > lw / 2) {
                ctx.strokeStyle = String(root.color);
                ctx.beginPath();
                const k = Math.PI * 2 / root.wavelength;
                for (let x = lw / 2; x <= end; x += 1.5) {
                    const y = mid + Math.sin(x * k - root.phase) * root.amplitude;
                    x === lw / 2 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
                }
                ctx.stroke();
            }
        }
    }

    Rectangle {
        x: Math.max(0, Math.min(root.width - width, root.handleX - width / 2))
        anchors.verticalCenter: parent.verticalCenter
        width: 4
        height: drag.pressed || drag.containsMouse ? 22 : 18
        radius: 2
        color: root.color
        Behavior on height { Anim { duration: Motion.duration.short } }
    }

    MouseArea {
        id: drag
        property real live: 0
        anchors.fill: parent
        anchors.topMargin: -4
        anchors.bottomMargin: -4
        enabled: root.seekable
        hoverEnabled: true
        preventStealing: true
        cursorShape: root.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor
        function at(x) { live = Math.max(0, Math.min(1, x / root.width)); }
        onPressed: m => at(m.x)
        onPositionChanged: m => { if (pressed) at(m.x); }
        onReleased: root.seek(live)
    }
}
