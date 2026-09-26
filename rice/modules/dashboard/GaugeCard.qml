import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Shared layout for UV, air quality and pressure: an arc gauge with the value
// and a level label in the middle and a caption underneath.
WeatherCard {
    id: root

    property real fraction: 0
    property string valueText: "--"
    property string unitText: ""
    property string levelText: ""
    property string caption: ""
    property color gaugeColor: accent

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.space.xs

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ArcGauge {
                id: gauge
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height + 14)
                height: width
                value: root.fraction * root.progress
                color: root.gaugeColor
                thickness: 9
            }

            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 2
                spacing: 0
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.valueText
                    font.pixelSize: 26
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: text !== ""
                    text: root.unitText
                    font.pixelSize: Tokens.font.xs
                    color: Theme.surfaceVariantFg
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.levelText
            font.weight: Font.DemiBold
            color: root.gaugeColor
        }
        StyledText {
            Layout.fillWidth: true
            visible: text !== ""
            horizontalAlignment: Text.AlignHCenter
            text: root.caption
            font.pixelSize: Tokens.font.s
            color: Theme.surfaceVariantFg
        }
    }
}
