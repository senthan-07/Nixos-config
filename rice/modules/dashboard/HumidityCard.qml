import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// Relative humidity with a gently moving water level.
WeatherCard {
    id: root

    readonly property var c: Weather.current
    readonly property real value: c && Weather.valid(c.humidity) ? c.humidity : NaN
    readonly property string feel: !Weather.valid(value) ? "" : value < 30 ? "Dry" : value < 60 ? "Comfortable" : value < 80 ? "Humid" : "Very humid"

    title: "Humidity"
    icon: "humidity_percentage"
    accent: "#5aa9ff"

    RowLayout {
        anchors.fill: parent
        spacing: Tokens.space.m

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.space.xs

            StyledText {
                text: Weather.valid(root.value) ? Math.round(root.value * root.progress) + "%" : "--"
                font.pixelSize: 40
                font.features: { "tnum": 1 }
            }
            StyledText {
                text: root.feel
                font.weight: Font.DemiBold
            }
            Item { Layout.fillHeight: true }
            StyledText {
                Layout.fillWidth: true
                text: "Dew point " + Weather.fmtTemp(root.c?.dewPoint)
                font.pixelSize: Tokens.font.s
                color: Theme.surfaceVariantFg
            }
        }

        ClippingRectangle {
            Layout.preferredWidth: 42
            Layout.fillHeight: true
            radius: 21
            color: Theme.alpha(root.accent, 0.14)

            Canvas {
                id: wave
                property real phase: 0
                readonly property real level: Weather.valid(root.value) ? root.value / 100 * root.progress : 0
                anchors.fill: parent
                onPhaseChanged: requestPaint()
                onLevelChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const top = height * (1 - level);
                    for (let layer = 0; layer < 2; layer++) {
                        ctx.beginPath();
                        ctx.moveTo(0, height);
                        for (let x = 0; x <= width; x += 2) {
                            const y = top + Math.sin(x / width * Math.PI * 2 + phase + layer * 2.2) * (layer ? 2.5 : 3.5);
                            ctx.lineTo(x, y);
                        }
                        ctx.lineTo(width, height);
                        ctx.closePath();
                        ctx.fillStyle = layer ? Qt.rgba(0.35, 0.66, 1, 0.9) : Qt.rgba(0.35, 0.66, 1, 0.4);
                        ctx.fill();
                    }
                }
                NumberAnimation on phase {
                    running: root.active && root.revealed
                    loops: Animation.Infinite
                    from: 0; to: Math.PI * 2
                    duration: 2600
                }
            }
        }
    }
}
