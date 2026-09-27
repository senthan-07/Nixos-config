import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Metric tile: badge + title on top, one-minute trend across the middle,
// big value and supporting text at the bottom. Everything stays inside the
// card. The badge gets spikier (and spins) as the load rises.
//   MetricTile { metric: "memory" }
Rectangle {
    id: root

    property string metric: "cpu"
    property bool running: true

    readonly property MetricInfo info: MetricInfo { metric: root.metric }
    readonly property bool dense: width < 220 || height < 150
    readonly property bool showTrend: info.available && height >= 120

    implicitWidth: 272
    implicitHeight: 176
    radius: Tokens.radius.xl
    color: info.container
    clip: true

    Accessible.role: Accessible.Indicator
    Accessible.name: `${info.label} ${info.valueText}, ${info.detail}`

    Behavior on color { ColorAnim {} }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.dense ? Tokens.space.m : Tokens.space.l
        spacing: Tokens.space.xs

        // ---- header
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.space.s

            CookieShape {
                id: badge
                readonly property real size: root.dense ? 30 : 36
                Layout.preferredWidth: size
                Layout.preferredHeight: size
                sides: root.info.level >= 0.82 ? 12 : root.info.level >= 0.48 ? 8 : 6
                depth: root.info.level >= 0.82 ? 0.16 : 0.1
                color: root.info.accent

                RotationAnimation on rotation {
                    running: root.running && root.visible && root.info.level > 0.48
                    from: 0; to: 360
                    duration: 24000 - root.info.level * 12000
                    loops: Animation.Infinite
                }

                Icon {
                    anchors.centerIn: parent
                    rotation: -parent.rotation
                    text: root.info.icon
                    size: root.dense ? 16 : 19
                    fill: 1
                    color: root.info.accentFg
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -2
                StyledText {
                    Layout.fillWidth: true
                    text: root.info.label
                    color: root.info.containerFg
                    font.pixelSize: root.dense ? Tokens.font.m : Tokens.font.l
                    font.weight: Font.Bold
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: !root.dense && text !== ""
                    text: root.metric === "cpu" ? "Processor load" : root.info.detail
                    color: Theme.alpha(root.info.containerFg, 0.72)
                    font.pixelSize: Tokens.font.xs
                }
            }

            // Temperature chip for the processor tile.
            Rectangle {
                visible: root.metric === "cpu" && SysStats.temperature > 0
                implicitWidth: tempRow.implicitWidth + Tokens.space.m
                implicitHeight: 24
                radius: 12
                color: Theme.alpha(root.info.containerFg, 0.1)
                Row {
                    id: tempRow
                    anchors.centerIn: parent
                    spacing: 2
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "thermostat"
                        size: 14
                        fill: 1
                        color: root.info.containerFg
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(SysStats.temperature) + "°"
                        color: root.info.containerFg
                        font.pixelSize: Tokens.font.s
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                }
            }
        }

        // ---- trend, full width
        Sparkline {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 18
            visible: root.showTrend
            active: visible && root.running
            values: root.info.history
            floor: 0.25
            headroom: 1.25
            color: root.info.accent
            lineWidth: 2.2
            fillOpacity: 0.22
        }
        Item { Layout.fillHeight: true; visible: !root.showTrend }

        // ---- value + supporting text
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.space.s

            StyledText {
                text: root.info.valueText
                color: root.info.containerFg
                font.family: CardStyle.display
                font.pixelSize: root.dense ? 28 : 36
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
            }
            Item { Layout.fillWidth: true }
            StyledText {
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 6
                visible: !root.dense && text !== ""
                text: root.info.available ? root.info.supporting : "Not available"
                color: Theme.alpha(root.info.containerFg, 0.72)
                font.pixelSize: Tokens.font.s
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
