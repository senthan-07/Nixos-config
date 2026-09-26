import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Live download / upload throughput with a shared one-minute chart.
CardFrame {
    id: root

    property bool running: true

    icon: "swap_vert"
    title: "Network"
    subtitle: Metrics.iface ? `${Metrics.iface} · ${Metrics.formatBytes(Metrics.rxTotal)} ↓  ${Metrics.formatBytes(Metrics.txTotal)} ↑` : "No interface"

    implicitWidth: 368
    implicitHeight: 176

    readonly property bool compact: height < 150

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.space.xs

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.space.l
            Rate { icon: "arrow_downward"; value: Metrics.rxRate; accent: Theme.primary; label: "Down" }
            Rate { icon: "arrow_upward"; value: Metrics.txRate; accent: Theme.tertiary; label: "Up" }
            Item { Layout.fillWidth: true }
        }

        Sparkline {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.compact
            active: visible && root.running
            values: Metrics.rxHistory
            secondaryValues: Metrics.txHistory
            color: Theme.primary
            secondaryColor: Theme.tertiary
            headroom: 1.25
            guides: true
            fillOpacity: 0.14
        }
    }

    component Rate: RowLayout {
        property string icon
        property string label
        property real value
        property color accent
        spacing: Tokens.space.s

        Rectangle {
            implicitWidth: 26
            implicitHeight: 26
            radius: 13
            color: Theme.alpha(parent.accent, 0.18)
            Icon {
                anchors.centerIn: parent
                text: parent.parent.icon
                size: 16
                color: parent.parent.accent
            }
        }
        ColumnLayout {
            spacing: -2
            StyledText {
                text: Metrics.formatRate(parent.parent.value)
                font.family: CardStyle.display
                font.pixelSize: Tokens.font.xl
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
            }
            StyledText {
                text: parent.parent.label
                color: Theme.surfaceVariantFg
                font.pixelSize: Tokens.font.xs
            }
        }
    }
}
