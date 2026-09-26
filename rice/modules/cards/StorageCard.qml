import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Capacity of each mounted filesystem (from `df`, refreshed every 30s).
CardFrame {
    id: root

    icon: "hard_drive"
    title: "Storage"
    subtitle: Metrics.disks.length > 0 ? `${Metrics.formatBytes(Metrics.disks.reduce((a, d) => a + d.avail, 0))} free` : ""

    implicitWidth: 368
    implicitHeight: 176

    function label(mount) {
        if (mount === "/") return "System";
        if (mount === "/home") return "Home";
        return mount.split("/").filter(s => s).pop() || mount;
    }

    EmptyState {
        anchors.centerIn: parent
        visible: Metrics.disks.length === 0
        busy: !Metrics.disksReady
        icon: "hard_drive"
        text: Metrics.disksReady ? "No disks found" : "Reading disks…"
    }

    ListView {
        id: list
        anchors.fill: parent
        visible: Metrics.disks.length > 0
        clip: true
        spacing: Tokens.space.s
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        model: Metrics.disks

        delegate: ColumnLayout {
            id: row
            required property var modelData
            readonly property bool hot: modelData.pct >= 0.9
            width: list.width
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    text: root.label(row.modelData.mount)
                    font.weight: Font.DemiBold
                }
                StyledText {
                    Layout.fillWidth: true
                    text: row.modelData.mount === "/" ? row.modelData.fs : row.modelData.mount
                    color: Theme.surfaceVariantFg
                    font.pixelSize: Tokens.font.xs
                    elide: Text.ElideMiddle
                }
                StyledText {
                    text: `${Metrics.formatBytes(row.modelData.used)} / ${Metrics.formatBytes(row.modelData.size)}`
                    color: Theme.surfaceVariantFg
                    font.pixelSize: Tokens.font.s
                    font.features: { "tnum": 1 }
                }
            }

            // M3 linear progress: active segment, gap, track, end stop.
            Item {
                Layout.fillWidth: true
                implicitHeight: 8
                Rectangle {
                    id: fill
                    height: parent.height
                    width: Math.max(height, (parent.width - 4) * row.modelData.pct)
                    radius: height / 2
                    color: row.hot ? Theme.error : Theme.primary
                    Behavior on width { Anim { duration: Motion.duration.long } }
                }
                Rectangle {
                    anchors.left: fill.right
                    anchors.leftMargin: 4
                    anchors.right: parent.right
                    height: parent.height
                    radius: height / 2
                    color: row.hot ? Theme.errorContainer : Theme.secondaryContainer
                }
            }
        }
    }
}
