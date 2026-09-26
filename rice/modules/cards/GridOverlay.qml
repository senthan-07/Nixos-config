import QtQuick
import qs.config

// Edit-mode grid guides: one soft rounded cell per grid slot plus a dot at
// each gap crossing. Painted once per size / theme change.
Canvas {
    id: root

    property int cols: 1
    property int rows: 1
    property real originX: 0
    property real originY: 0
    property color cellColor: Theme.alpha(Theme.surfaceFg, 0.05)
    property color dotColor: Theme.alpha(Theme.primary, 0.5)

    onColsChanged: requestPaint()
    onRowsChanged: requestPaint()
    onOriginXChanged: requestPaint()
    onOriginYChanged: requestPaint()
    onCellColorChanged: requestPaint()
    onDotColorChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const c = CardStyle.cell, p = CardStyle.pitch, r = 14;
        ctx.fillStyle = cellColor;
        for (let y = 0; y < rows; y++)
            for (let x = 0; x < cols; x++) {
                const px = originX + x * p, py = originY + y * p;
                ctx.beginPath();
                ctx.roundedRect(px, py, c, c, r, r);
                ctx.fill();
            }
        ctx.fillStyle = dotColor;
        for (let y = 1; y < rows; y++)
            for (let x = 1; x < cols; x++) {
                ctx.beginPath();
                ctx.arc(originX + x * p - CardStyle.gap / 2, originY + y * p - CardStyle.gap / 2, 1.5, 0, Math.PI * 2);
                ctx.fill();
            }
    }
}
