import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Expressive metric tile: label, one-minute trend and a big value, with a
// cookie badge in the corner that grows spikier as the load rises.
//   MetricTile { metric: "memory" }
Rectangle {
    id: root

    property string metric: "cpu"
    property bool running: true

    readonly property MetricInfo info: MetricInfo { metric: root.metric }
    readonly property bool dense: width < 220 || height < 150
    readonly property real badgeSize: Math.min(width * 0.4, height * 0.62, 104) * (1 + info.level * 0.12)

    implicitWidth: 272
    implicitHeight: 176
    radius: Tokens.radius.xl
    color: info.container
    clip: true

    Accessible.role: Accessible.Indicator
    Accessible.name: `${info.label} ${info.valueText}, ${info.detail}`

    Behavior on color { ColorAnim {} }

    CookieShape {
        id: badge
        width: root.badgeSize
        height: width
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -width * 0.16
        anchors.bottomMargin: -height * 0.18
        sides: root.info.level >= 0.82 ? 12 : root.info.level >= 0.48 ? 8 : 5
        depth: root.info.level >= 0.82 ? 0.16 : 0.1
        color: root.info.accent
        rotation: 18

        Behavior on width { Anim { duration: Motion.duration.long; easing.bezierCurve: Motion.curve.springDefault } }

        RotationAnimation on rotation {
            running: root.running && root.visible && root.info.level > 0.48
            from: 18; to: 378
            duration: 24000 - root.info.level * 12000
            loops: Animation.Infinite
        }

        Icon {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: -parent.width * 0.08
            anchors.verticalCenterOffset: -parent.height * 0.08
            rotation: -parent.rotation
            text: root.info.icon
            size: root.dense ? 20 : 26
            fill: 1
            color: root.info.accentFg
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.dense ? Tokens.space.m : Tokens.space.l
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: root.info.label
                color: root.info.containerFg
                font.pixelSize: root.dense ? Tokens.font.l : Tokens.font.xl
                font.weight: Font.Bold
            }
            // Temperature badge for the processor tile.
            Icon {
                visible: root.metric === "cpu" && SysStats.temperature > 0
                text: "thermostat"
                size: 16
                fill: 1
                color: Theme.alpha(root.info.containerFg, 0.8)
            }
            StyledText {
                visible: root.metric === "cpu" && SysStats.temperature > 0
                text: Math.round(SysStats.temperature) + "°"
                color: Theme.alpha(root.info.containerFg, 0.85)
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.rightMargin: root.badgeSize * 0.4
            visible: !root.dense && text !== ""
            text: root.metric === "cpu" ? "Processor load" : root.info.detail
            color: Theme.alpha(root.info.containerFg, 0.75)
            font.pixelSize: Tokens.font.s
        }

        Sparkline {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 20
            Layout.topMargin: Tokens.space.xs
            Layout.rightMargin: root.badgeSize * 0.55
            visible: root.info.available && root.height >= 120
            active: visible && root.running
            values: root.info.history
            floor: 0.25
            headroom: 1.25
            color: root.info.accent
            lineWidth: 2.2
            fillOpacity: 0.2
        }

        Item {
            Layout.fillHeight: true
            visible: !(root.info.available && root.height >= 120)
        }

        StyledText {
            Layout.fillWidth: true
            Layout.rightMargin: root.badgeSize * 0.45
            text: root.info.valueText
            color: root.info.containerFg
            font.family: CardStyle.display
            font.pixelSize: root.dense ? 30 : 40
            font.weight: Font.Bold
            font.features: { "tnum": 1 }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.rightMargin: root.badgeSize * 0.55
            visible: !root.dense && text !== ""
            text: root.info.available ? root.info.supporting : "Not available on this machine"
            color: Theme.alpha(root.info.containerFg, 0.75)
            font.pixelSize: Tokens.font.s
        }
    }
}
