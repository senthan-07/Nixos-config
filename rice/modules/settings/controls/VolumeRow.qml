import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.config
import qs.components

// Volume control for one Pipewire node (device or application stream):
// icon, name, detail line, mute toggle, slider and live peak meter.
Surface {
    id: root

    required property PwNode node
    property string title: node?.description || node?.nickname || node?.name || "Unknown"
    property string detail
    property string icon: "volume_up"
    property string appIcon
    property bool meter: true
    property real maxVolume: 1.5

    readonly property real volume: node?.audio?.volume ?? 0
    readonly property bool muted: node?.audio?.muted ?? false
    readonly property bool ready: node?.ready ?? false

    signal setVolume(real v)
    signal toggleMute()

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + Tokens.space.m * 2
    radius: Tokens.radius.m
    base: Theme.alpha(Theme.surfaceContainer, 0)
    opacity: ready ? 1 : 0.5

    PwNodePeakMonitor {
        id: peak
        node: root.node
        enabled: root.meter && root.visible && root.ready
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tokens.space.m
        anchors.rightMargin: Tokens.space.m
        spacing: Tokens.space.xs

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.space.m

            Item {
                implicitWidth: 40
                implicitHeight: 40
                IconBadge {
                    anchors.centerIn: parent
                    visible: root.appIcon === ""
                    icon: root.muted ? "volume_off" : root.icon
                }
                AppIcon {
                    anchors.centerIn: parent
                    visible: root.appIcon !== ""
                    name: root.appIcon
                    size: 32
                    opacity: root.muted ? 0.4 : 1
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    text: root.title
                    font.weight: Font.Medium
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.detail
                    font.pixelSize: Tokens.font.s
                    color: Theme.surfaceVariantFg
                }
            }
            StyledText {
                text: root.muted ? "Muted" : `${Math.round(root.volume * 100)}%`
                font.features: { "tnum": 1 }
                color: root.volume > 1 && !root.muted ? Theme.tertiary : Theme.surfaceVariantFg
            }
            IconButton {
                icon: root.muted ? "volume_off" : "volume_up"
                toggled: root.muted
                onClicked: root.toggleMute()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 40 + Tokens.space.m
            spacing: Tokens.space.m

            LevelSlider {
                Layout.fillWidth: true
                from: 0
                to: root.maxVolume
                step: 0.01
                value: root.volume
                accent: root.muted ? Theme.outline : root.volume > 1 ? Theme.tertiary : Theme.primary
                onMoved: v => root.setVolume(v)
            }
        }

        // Peak meter (thin bar under the slider)
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 40 + Tokens.space.m
            visible: root.meter
            implicitHeight: 3
            radius: 2
            color: Theme.surfaceHighest
            Rectangle {
                height: parent.height
                radius: 2
                width: parent.width * Math.min(1, root.muted ? 0 : peak.peak)
                color: Theme.secondary
                Behavior on width { NumberAnimation { duration: 80 } }
            }
        }
    }
}
