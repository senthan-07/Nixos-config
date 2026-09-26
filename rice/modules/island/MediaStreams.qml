import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.config
import qs.components
import qs.services

// Audio streams of one source (an app, or a player with several tabs):
// per-stream mute and volume. Used by the island Media tab.
ColumnLayout {
    id: root

    required property var source            // Media.sources entry
    property bool showBack: false
    signal back()

    spacing: Tokens.space.s

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.space.m

        IconButton {
            visible: root.showBack
            icon: "arrow_back"
            size: 34
            onClicked: root.back()
        }
        AppIcon {
            size: 40
            name: root.source?.icon ?? ""
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            StyledText {
                Layout.fillWidth: true
                text: root.source?.name ?? ""
                font.pixelSize: Tokens.font.xl
                font.weight: Font.DemiBold
            }
            StyledText {
                Layout.fillWidth: true
                text: {
                    const n = root.source?.streams.length ?? 0;
                    const what = n === 1 ? "1 audio stream" : `${n} audio streams`;
                    return root.source?.player ? what : `${what} · no media controls`;
                }
                color: Theme.surfaceVariantFg
            }
        }
    }

    Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: list
            width: parent.width
            spacing: Tokens.space.xs

            Repeater {
                model: root.source?.streams ?? []

                Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property PwNode node: modelData
                    readonly property bool muted: node?.audio?.muted ?? false

                    Layout.fillWidth: true
                    implicitHeight: 52
                    radius: Tokens.radius.l
                    color: Theme.alpha(Theme.surfaceHigh, 0.7)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.space.m
                        anchors.rightMargin: Tokens.space.m
                        spacing: Tokens.space.m

                        IconButton {
                            size: 34
                            icon: row.muted ? "volume_off" : "volume_up"
                            toggled: row.muted
                            onClicked: if (row.node?.audio) row.node.audio.muted = !row.node.audio.muted
                        }
                        StyledText {
                            Layout.preferredWidth: 130
                            text: Media.streamTitle(row.node, row.index)
                            font.weight: Font.Medium
                        }
                        Slider {
                            Layout.fillWidth: true
                            implicitHeight: 28
                            value: Math.min(1, row.node?.audio?.volume ?? 0)
                            onMoved: v => {
                                if (!row.node?.audio) return;
                                row.node.audio.muted = false;
                                row.node.audio.volume = v;
                            }
                        }
                        StyledText {
                            Layout.preferredWidth: 38
                            horizontalAlignment: Text.AlignRight
                            text: row.muted ? "Muted" : `${Math.round((row.node?.audio?.volume ?? 0) * 100)}%`
                            font.pixelSize: Tokens.font.s
                            font.features: { "tnum": 1 }
                            color: Theme.surfaceVariantFg
                        }
                    }
                }
            }
        }
    }
}
