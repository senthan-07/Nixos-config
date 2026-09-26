import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Visibility as receding "distance" lines: the clearer the air, the more of
// them are lit.
WeatherCard {
    id: root

    readonly property var c: Weather.current
    readonly property real dist: c && Weather.valid(c.visibility) ? c.visibility : NaN
    readonly property real km: Weather.unit === "F" ? dist * 1.609344 : dist
    readonly property real level: Weather.valid(km) ? Math.min(1, km / 20) : 0
    readonly property string feel: !Weather.valid(km) ? "" : km >= 16 ? "Crystal clear" : km >= 10 ? "Clear" : km >= 5 ? "Good" : km >= 2 ? "Hazy" : km >= 1 ? "Poor" : "Fog"

    title: "Visibility"
    icon: "visibility"
    accent: Theme.secondary

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.space.xs

        RowLayout {
            spacing: Tokens.space.xs
            StyledText {
                text: Weather.valid(root.dist) ? (root.dist >= 10 ? Math.round(root.dist) : root.dist.toFixed(1)) : "--"
                font.pixelSize: 40
                font.features: { "tnum": 1 }
            }
            StyledText {
                Layout.alignment: Qt.AlignBaseline
                text: Weather.distanceUnit
                font.pixelSize: Tokens.font.l
                color: Theme.surfaceVariantFg
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Column {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                spacing: 4
                Repeater {
                    model: 5
                    Rectangle {
                        required property int index
                        // index 0 is the farthest (top, narrowest) line.
                        readonly property bool lit: (5 - index) / 5 <= root.level * root.progress + 0.001
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width * (0.35 + index * 0.16)
                        height: 5
                        radius: 2.5
                        color: lit ? Theme.secondary : Theme.alpha(Theme.secondary, 0.16)
                        Behavior on color { ColorAnim {} }
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: root.feel
            font.weight: Font.DemiBold
            color: Theme.surfaceVariantFg
        }
    }
}
