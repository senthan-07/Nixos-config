import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Today's precipitation total plus the chance of rain over the next 12 hours.
WeatherCard {
    id: root

    readonly property var today: Weather.daily.length ? Weather.daily[0] : null
    readonly property var hours: Weather.hourly.slice(0, 12)

    readonly property color rain: "#5aa9ff"

    title: "Precipitation"
    icon: "water_drop"
    accent: "#5aa9ff"

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.space.xs

        RowLayout {
            spacing: Tokens.space.xs
            StyledText {
                text: root.today ? Weather.fmt(root.today.precipSum, Weather.unit === "F" ? 2 : 1) : "--"
                font.pixelSize: 34
                font.features: { "tnum": 1 }
            }
            StyledText {
                Layout.alignment: Qt.AlignBaseline
                text: Weather.precipUnit
                font.pixelSize: Tokens.font.l
                color: Theme.surfaceVariantFg
            }
        }
        StyledText {
            Layout.fillWidth: true
            text: root.today ? `${Math.round(root.today.precipProb)}% chance today` : ""
            font.pixelSize: Tokens.font.s
            color: Theme.surfaceVariantFg
        }

        Row {
            id: bars
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 3
            readonly property real barWidth: (width - spacing * 11) / 12
            Repeater {
                model: root.hours
                Item {
                    required property var modelData
                    width: bars.barWidth
                    height: bars.height
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: parent.height
                        radius: width / 2
                        color: Theme.alpha(root.rain, 0.14)
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.max(width, parent.height * modelData.precipProb / 100 * root.progress)
                        radius: width / 2
                        color: Theme.alpha(root.rain, 0.4 + modelData.precipProb / 170)
                    }
                }
            }
        }
        StyledText {
            Layout.fillWidth: true
            text: "Next 12 hours"
            font.pixelSize: Tokens.font.xs
            color: Theme.surfaceVariantFg
        }
    }
}
