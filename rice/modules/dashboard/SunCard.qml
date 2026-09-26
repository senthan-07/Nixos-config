import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.config
import qs.components
import qs.services

// Sun path from sunrise to sunset with the sun's current position.
WeatherCard {
    id: root

    readonly property var today: Weather.daily.length ? Weather.daily[0] : null
    readonly property var tomorrow: Weather.daily.length > 1 ? Weather.daily[1] : null
    readonly property real now: Time.now.getTime() + Weather.timeShift
    readonly property real rise: today ? today.sunrise.getTime() : NaN
    readonly property real set: today ? today.sunset.getTime() : NaN
    readonly property bool isDay: now >= rise && now < set
    readonly property real dayFrac: Weather.valid(rise) ? Math.max(0, Math.min(1, (now - rise) / (set - rise))) : 0
    readonly property string countdown: {
        if (!today) return "";
        let target = now < rise ? rise : now < set ? set : tomorrow ? tomorrow.sunrise.getTime() : NaN;
        if (!Weather.valid(target)) return "";
        const mins = Math.max(0, Math.round((target - now) / 60000));
        const txt = mins >= 60 ? `${Math.floor(mins / 60)} h ${mins % 60} min` : `${mins} min`;
        return (isDay ? "Sunset in " : "Sunrise in ") + txt;
    }

    title: "Sunrise & sunset"
    icon: "wb_twilight"
    accent: "#ffb547"

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.space.xs

        StyledText {
            Layout.fillWidth: true
            text: root.countdown
            font.weight: Font.DemiBold
        }

        Item {
            id: sky
            Layout.fillWidth: true
            Layout.fillHeight: true
            readonly property real baseY: height - 4
            readonly property real rx: width / 2 - 8
            readonly property real ry: Math.max(10, height - 14)
            readonly property real frac: root.dayFrac * root.progress
            readonly property real angle: Math.PI * (1 - frac)

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                // Full path, dashed.
                ShapePath {
                    strokeColor: Theme.alpha(Theme.outline, 0.7)
                    strokeWidth: 1.5
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [3, 3]
                    fillColor: "transparent"
                    PathAngleArc {
                        centerX: sky.width / 2; centerY: sky.baseY
                        radiusX: sky.rx; radiusY: sky.ry
                        startAngle: 180; sweepAngle: 180
                    }
                }
                // Travelled part.
                ShapePath {
                    strokeColor: root.isDay ? "#ffb547" : "transparent"
                    strokeWidth: 3
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathAngleArc {
                        centerX: sky.width / 2; centerY: sky.baseY
                        radiusX: sky.rx; radiusY: sky.ry
                        startAngle: 180; sweepAngle: Math.max(0.1, 180 * sky.frac)
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                y: sky.baseY
                color: Theme.outlineVariant
            }

            Rectangle {
                visible: root.isDay
                width: 16; height: 16; radius: 8
                x: sky.width / 2 + Math.cos(sky.angle) * sky.rx - width / 2
                y: sky.baseY - Math.sin(sky.angle) * sky.ry - height / 2
                color: "#ffc94a"
                border.width: 3
                border.color: Qt.rgba(1, 0.79, 0.29, 0.35)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Icon { text: "north"; size: 14; color: "#ffb547" }
            StyledText {
                text: Weather.formatTime(root.today?.sunrise)
                font.pixelSize: Tokens.font.s
                font.features: { "tnum": 1 }
            }
            Item { Layout.fillWidth: true }
            Icon { text: "south"; size: 14; color: Theme.surfaceVariantFg }
            StyledText {
                text: Weather.formatTime(root.today?.sunset)
                font.pixelSize: Tokens.font.s
                font.features: { "tnum": 1 }
            }
        }
    }
}
