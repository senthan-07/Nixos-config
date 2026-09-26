import QtQuick
import qs.config
import qs.components
import qs.services

// Next 24 hours: temperature curve with labels, conditions, chance of rain.
// Drag or scroll sideways (touchpad / shift+wheel) to move through the day.
WeatherCard {
    id: root

    readonly property var hours: Weather.hourly
    readonly property real colW: 54
    readonly property real chartTop: 26
    readonly property real chartBottom: 72
    readonly property real minT: hours.length ? Math.min(...hours.map(h => h.temp)) : 0
    readonly property real maxT: hours.length ? Math.max(...hours.map(h => h.temp)) : 1

    // Small swings are kept small: the scale spans at least 8 degrees.
    function yFor(t) {
        const span = Math.max(8, maxT - minT);
        const mid = (maxT + minT) / 2;
        return (chartTop + chartBottom) / 2 - (t - mid) / span * (chartBottom - chartTop);
    }

    title: "Hourly forecast"
    icon: "schedule"
    implicitHeight: 34 + 196

    Flickable {
        id: strip
        anchors.fill: parent
        anchors.leftMargin: -Tokens.space.s
        anchors.rightMargin: -Tokens.space.s
        contentWidth: root.hours.length * root.colW
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        // Revealed left-to-right when the card first appears.
        Item {
            width: strip.contentWidth * root.progress
            height: parent.height
            clip: true

            Canvas {
                id: chart
                width: strip.contentWidth
                height: root.chartBottom + 40
                readonly property color line: Theme.primary
                onLineChanged: requestPaint()
                onWidthChanged: requestPaint()
                Connections {
                    target: root
                    function onHoursChanged() { chart.requestPaint(); }
                }
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const pts = root.hours.map((h, i) => ({ x: i * root.colW + root.colW / 2, y: root.yFor(h.temp) }));
                    if (pts.length < 2) return;
                    const curve = () => {
                        ctx.moveTo(pts[0].x, pts[0].y);
                        for (let i = 0; i < pts.length - 1; i++) {
                            const p0 = pts[Math.max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[Math.min(pts.length - 1, i + 2)];
                            ctx.bezierCurveTo(p1.x + (p2.x - p0.x) / 6, p1.y + (p2.y - p0.y) / 6,
                                              p2.x - (p3.x - p1.x) / 6, p2.y - (p3.y - p1.y) / 6, p2.x, p2.y);
                        }
                    };
                    const grad = ctx.createLinearGradient(0, root.chartTop, 0, height);
                    grad.addColorStop(0, Qt.rgba(line.r, line.g, line.b, 0.28));
                    grad.addColorStop(1, Qt.rgba(line.r, line.g, line.b, 0));
                    ctx.beginPath();
                    curve();
                    ctx.lineTo(pts[pts.length - 1].x, height);
                    ctx.lineTo(pts[0].x, height);
                    ctx.closePath();
                    ctx.fillStyle = grad;
                    ctx.fill();

                    ctx.beginPath();
                    curve();
                    ctx.lineWidth = 2.5;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = line;
                    ctx.stroke();
                }
            }

            Repeater {
                model: root.hours

                Item {
                    id: col
                    required property var modelData
                    required property int index
                    readonly property bool now: index === 0
                    x: index * root.colW
                    width: root.colW
                    height: strip.height

                    Rectangle {
                        visible: col.now
                        anchors.fill: parent
                        anchors.leftMargin: 3
                        anchors.rightMargin: 3
                        radius: Tokens.radius.l
                        color: Theme.alpha(Theme.primary, 0.10)
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.yFor(col.modelData.temp) - height - 5
                        text: Math.round(col.modelData.temp) + "°"
                        font.pixelSize: Tokens.font.s
                        font.weight: col.now ? Font.Bold : Font.DemiBold
                    }
                    Rectangle {
                        x: parent.width / 2 - 4
                        y: root.yFor(col.modelData.temp) - 4
                        width: 8; height: 8; radius: 4
                        color: col.now ? Theme.primary : Theme.surfaceContainer
                        border.width: 2
                        border.color: Theme.primary
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.chartBottom + 20
                        spacing: 1
                        opacity: col.modelData.precipProb >= 10 ? 1 : 0.35
                        Icon { text: "water_drop"; size: 11; fill: 1; color: "#5aa9ff"; anchors.verticalCenter: parent.verticalCenter }
                        StyledText {
                            text: Math.round(col.modelData.precipProb) + "%"
                            font.pixelSize: Tokens.font.xs
                            color: col.modelData.precipProb >= 10 ? "#5aa9ff" : Theme.surfaceVariantFg
                        }
                    }

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.chartBottom + 42
                        text: col.modelData.icon
                        size: 24
                        fill: 1
                        color: col.modelData.isDay ? Theme.surfaceFg : Theme.surfaceVariantFg
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: root.chartBottom + 76
                        text: col.now ? "Now" : Qt.formatTime(col.modelData.time, Settings.data.use24h ? "HH:mm" : "h AP")
                        font.pixelSize: Tokens.font.s
                        font.weight: col.now ? Font.Bold : Font.Normal
                        color: col.now ? Theme.primary : Theme.surfaceVariantFg
                    }
                }
            }
        }
    }

    // Vertical wheel keeps scrolling the page; sideways scroll moves the strip.
    MouseArea {
        anchors.fill: strip
        acceptedButtons: Qt.NoButton
        onWheel: w => {
            const dx = w.angleDelta.x !== 0 ? w.angleDelta.x : (w.modifiers & Qt.ShiftModifier ? w.angleDelta.y : 0);
            if (dx === 0) { w.accepted = false; return; }
            strip.contentX = Math.max(0, Math.min(strip.contentWidth - strip.width, strip.contentX - dx));
        }
    }

    StyledText {
        anchors.centerIn: parent
        visible: root.hours.length === 0
        text: "No hourly data"
        color: Theme.surfaceVariantFg
    }
}
