import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.config
import qs.components
import qs.services

Chip {
    id: root

    readonly property MprisPlayer player: Media.active

    interactive: true
    padding: Tokens.space.xs
    onClicked: m => m.button === Qt.RightButton ? Media.cycle() : player?.togglePlaying()
    onWheel: w => w.angleDelta.y > 0 ? player?.previous() : player?.next()

    Item {
        implicitWidth: 22
        implicitHeight: 22

        Ring {
            anchors.fill: parent
            thickness: 2
            value: root.player && root.player.length > 0 ? root.player.position / root.player.length : 0
        }
        Icon {
            anchors.centerIn: parent
            text: root.player?.isPlaying ? "pause" : "play_arrow"
            size: 14
            fill: 1
            color: Theme.primary
        }
    }

    StyledText {
        Layout.fillWidth: true
        Layout.maximumWidth: Math.max(0, root.Layout.maximumWidth - 40)
        Layout.rightMargin: Tokens.space.s
        text: root.player ? [root.player.trackTitle, root.player.trackArtist].filter(s => s).join("  ·  ") : ""
    }

    // Position is not a notifying property; poll while playing.
    Timer {
        running: root.player?.isPlaying ?? false
        repeat: true
        interval: 1000
        onTriggered: root.player.positionChanged()
    }
}
