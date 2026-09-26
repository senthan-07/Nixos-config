import QtQuick
import qs.config

// Scrolling line chart for a rolling history. New samples slide in from the
// right over one sample interval instead of jumping: the canvas is painted
// once per sample, one step wider than the chart, and only translated.
//   Sparkline { values: Metrics.cpuHistory; maximum: 1 }
Item {
    id: root

    property var values: []
    property var secondaryValues: []
    property color color: Theme.primary
    property color secondaryColor: Theme.tertiary
    property color guideColor: Theme.alpha(Theme.surfaceFg, 0.1)
    property real maximum: 0             // 0 = auto-scale with headroom
    property real floor: 0               // smallest auto-scale maximum
    property real headroom: 1.2
    property int slots: 60
    property int interval: 1000
    property real lineWidth: 2
    property real fillOpacity: 0.16
    property bool guides: false
    property bool active: visible

    property real slide: 1
    readonly property real dataMax: {
        let m = 0;
        for (const s of [values || [], secondaryValues || []])
            for (const v of s) if (isFinite(v)) m = Math.max(m, v);
        return m;
    }
    readonly property real scaleMax: maximum > 0 ? maximum : Math.max(floor, 1e-6, dataMax * headroom)

    implicitHeight: 56

    readonly property real step: width / Math.max(1, slots - 1)

    clip: true
    onValuesChanged: {
        canvas.requestPaint();
        if (active) slider.restart(); else slide = 1;
    }
    onSecondaryValuesChanged: canvas.requestPaint()
    onScaleMaxChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onSecondaryColorChanged: canvas.requestPaint()
    onActiveChanged: canvas.requestPaint()

    NumberAnimation {
        id: slider
        target: root
        property: "slide"
        from: 0; to: 1
        duration: root.interval
    }

    Canvas {
        id: canvas
        x: -root.step * root.slide
        width: root.width + root.step
        height: root.height
        visible: root.active
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (!root.active || width < 2 || height < 2) return;
            const top = root.lineWidth * 2, bottom = height - root.lineWidth;

            if (root.guides) {
                ctx.strokeStyle = root.guideColor;
                ctx.lineWidth = 1;
                for (let g = 1; g <= 3; g++) {
                    const y = Math.round(top + (bottom - top) * g / 4) + 0.5;
                    ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke();
                }
            }

            function series(pts, color, fill) {
                if (!pts || pts.length < 2) return;
                const step = root.step;
                const x0 = width - (pts.length - 1) * step;
                const xy = pts.map((v, i) => [x0 + i * step, bottom - Math.max(0, Math.min(1, v / root.scaleMax)) * (bottom - top)]);
                // Smooth with midpoint quadratics.
                const trace = () => {
                    ctx.beginPath();
                    ctx.moveTo(xy[0][0], xy[0][1]);
                    for (let i = 1; i < xy.length - 1; i++) {
                        const mx = (xy[i][0] + xy[i + 1][0]) / 2, my = (xy[i][1] + xy[i + 1][1]) / 2;
                        ctx.quadraticCurveTo(xy[i][0], xy[i][1], mx, my);
                    }
                    ctx.lineTo(xy[xy.length - 1][0], xy[xy.length - 1][1]);
                };
                if (fill) {
                    trace();
                    ctx.lineTo(xy[xy.length - 1][0], height);
                    ctx.lineTo(xy[0][0], height);
                    ctx.closePath();
                    const grad = ctx.createLinearGradient(0, top, 0, height);
                    grad.addColorStop(0, Theme.alpha(color, root.fillOpacity * 1.6));
                    grad.addColorStop(1, Theme.alpha(color, 0));
                    ctx.fillStyle = grad;
                    ctx.fill();
                }
                trace();
                ctx.lineWidth = root.lineWidth;
                ctx.lineJoin = "round";
                ctx.lineCap = "round";
                ctx.strokeStyle = color;
                ctx.stroke();
            }

            series(root.values, root.color, root.fillOpacity > 0);
            series(root.secondaryValues, root.secondaryColor, root.fillOpacity > 0);
        }
    }
}
