import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.config
import qs.components

// A cookie-shaped vessel that fills with liquid to the metric's level.
//   LiquidMetric { metric: "cpu" }       // cpu | memory | gpu | temp
Item {
    id: root

    property string metric: "cpu"
    property int sides: ({ cpu: 4, memory: 6, gpu: 8, temp: 9 })[metric] || 6
    property bool running: true
    property bool elevated: true

    readonly property MetricInfo info: MetricInfo { metric: root.metric }

    implicitWidth: 140
    implicitHeight: 140

    Accessible.role: Accessible.Indicator
    Accessible.name: `${info.label} ${info.valueText}`

    Item {
        id: vessel
        anchors.centerIn: parent
        width: Math.max(56, Math.min(parent.width, parent.height))
        height: width

        CookieShape {
            id: body
            anchors.fill: parent
            sides: root.sides
            depth: 0.07 + 0.05 * root.info.level
            color: root.info.container
            layer.enabled: root.elevated
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.alpha(Theme.shadow, 0.35)
                shadowBlur: 0.7
                shadowVerticalOffset: 3
                autoPaddingEnabled: true
            }
        }

        // Liquid clipped to the cookie through an alpha mask of the same shape.
        Item {
            anchors.fill: parent
            visible: root.info.available
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: mask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }

            Liquid {
                anchors.fill: parent
                level: root.info.level
                running: root.running
                color: CardStyle.mix(root.info.container, root.info.accent, 0.4)
                backColor: CardStyle.mix(root.info.container, root.info.accent, 0.2)
            }
        }

        CookieShape {
            id: mask
            anchors.fill: parent
            sides: body.sides
            depth: body.depth
            color: "white"
            visible: false
            layer.enabled: true
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width * 0.78
            spacing: -2

            Icon {
                Layout.alignment: Qt.AlignHCenter
                text: root.info.icon
                size: Math.max(16, vessel.width * 0.16)
                fill: 1
                color: root.info.containerFg
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.info.valueText
                color: root.info.containerFg
                font.family: CardStyle.display
                font.pixelSize: Math.max(14, vessel.width * 0.2)
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.info.label
                color: Theme.alpha(root.info.containerFg, 0.8)
                font.pixelSize: Math.max(Tokens.font.xs, vessel.width * 0.085)
                font.weight: Font.DemiBold
                visible: vessel.width >= 80
            }
        }
    }
}
