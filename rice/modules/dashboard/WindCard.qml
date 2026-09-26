import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.config
import qs.components
import qs.services

// Compass with an arrow pointing where the wind blows to.
WeatherCard {
    id: root

    readonly property var c: Weather.current
    readonly property real dir: c && Weather.valid(c.windDir) ? c.windDir : 0
    property real sway: 0

    title: "Wind · " + Weather.compass(c?.windDir)
    icon: "air"
    accent: Theme.secondary

    SequentialAnimation on sway {
        running: root.active && root.revealed
        loops: Animation.Infinite
        NumberAnimation { to: 5; duration: 1400; easing.type: Easing.InOutSine }
        NumberAnimation { to: -4; duration: 1700; easing.type: Easing.InOutSine }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.space.xs

        Item {
            id: dial
            Layout.fillWidth: true
            Layout.fillHeight: true
            readonly property real d: Math.min(width, height)

            Rectangle {
                anchors.centerIn: parent
                width: dial.d; height: dial.d; radius: dial.d / 2
                color: Theme.alpha(Theme.secondary, 0.08)
                border.width: 1
                border.color: Theme.alpha(Theme.outlineVariant, 0.6)
            }

            // Tick marks every 30°.
            Repeater {
                model: 12
                Rectangle {
                    required property int index
                    x: dial.width / 2 - width / 2
                    y: (dial.height - dial.d) / 2 + 4
                    width: 2
                    height: index % 3 ? 4 : 0
                    radius: 1
                    color: Theme.outline
                    transform: Rotation { origin.x: 1; origin.y: dial.d / 2 - 4; angle: index * 30 }
                }
            }

            Repeater {
                model: ["N", "E", "S", "W"]
                StyledText {
                    required property string modelData
                    required property int index
                    readonly property real a: index * Math.PI / 2 - Math.PI / 2
                    x: dial.width / 2 + Math.cos(a) * (dial.d / 2 - 11) - width / 2
                    y: dial.height / 2 + Math.sin(a) * (dial.d / 2 - 11) - height / 2
                    text: modelData
                    font.pixelSize: Tokens.font.xs
                    font.weight: Font.Bold
                    color: index === 0 ? Theme.error : Theme.surfaceVariantFg
                }
            }

            Item {
                id: needle
                anchors.centerIn: parent
                width: dial.d - 30
                height: width
                rotation: (root.dir + 180) * root.progress + root.sway
                readonly property real mid: width / 2
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeWidth: -1
                        fillColor: Theme.secondary
                        // Arrow head at the top, slim tail below.
                        startX: needle.mid; startY: 0
                        PathLine { x: needle.mid + 8; y: 14 }
                        PathLine { x: needle.mid + 2; y: 12 }
                        PathLine { x: needle.mid + 2; y: needle.height - 4 }
                        PathLine { x: needle.mid - 2; y: needle.height - 4 }
                        PathLine { x: needle.mid - 2; y: 12 }
                        PathLine { x: needle.mid - 8; y: 14 }
                        PathLine { x: needle.mid; y: 0 }
                    }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: dial.d * 0.46
                height: width
                radius: width / 2
                color: Theme.surfaceContainer
                Column {
                    anchors.centerIn: parent
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Weather.fmt(root.c?.windSpeed)
                        font.pixelSize: Tokens.font.xl
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Weather.speedUnit
                        font.pixelSize: Tokens.font.xs
                        color: Theme.surfaceVariantFg
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: `Gusts ${Weather.fmt(root.c?.windGusts)} ${Weather.speedUnit}`
            font.pixelSize: Tokens.font.s
            color: Theme.surfaceVariantFg
        }
    }
}
