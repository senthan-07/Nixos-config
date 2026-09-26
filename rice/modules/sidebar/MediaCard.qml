import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.config
import qs.components
import qs.services
import qs.modules.island

// Sidebar player, styled like the island's Media tab: album-art tint, wavy
// seek bar, transport + mute, and ‹ › to step through players / audio apps.
ClippingRectangle {
    id: root

    readonly property var src: Media.current
    readonly property MprisPlayer player: src?.player ?? null
    readonly property color accent: MediaPalette.accent
    readonly property color accentFg: MediaPalette.accentFg
    readonly property color fg: MediaPalette.containerFg

    Layout.fillWidth: true
    visible: player !== null
    implicitHeight: 164
    radius: Tokens.radius.xl
    color: MediaPalette.surface

    // ---- position / length (Zen drops the length after a seek; keep the last good one)
    property real position: player?.position ?? 0
    readonly property string trackKey: player ? `${player.dbusName}|${player.trackTitle}|${player.trackArtist}` : ""
    readonly property real rawLength: player && player.length > 0 && isFinite(player.length) ? player.length : 0
    property real length: 0
    property string lengthKey: ""
    function updateLength() {
        if (trackKey !== lengthKey) { lengthKey = trackKey; length = rawLength; }
        else if (rawLength > 0 && rawLength >= position) length = rawLength;
        else if (length <= 0) length = rawLength;
    }
    onRawLengthChanged: updateLength()
    onTrackKeyChanged: updateLength()
    Component.onCompleted: updateLength()

    Timer {
        running: root.visible && (root.player?.isPlaying ?? false)
        interval: 500
        repeat: true
        triggeredOnStart: true
        onTriggered: root.position = root.player?.position ?? 0
    }

    // ---- mute this source's streams (or the player's volume)
    readonly property var muteStreams: (src?.streams ?? []).filter(n => n.audio)
    readonly property bool muted: muteStreams.length ? muteStreams.every(n => n.audio.muted)
        : (player?.volumeSupported ?? false) && player.volume === 0
    property real savedVolume: 1
    function toggleMute() {
        if (muteStreams.length) {
            const to = !muted;
            muteStreams.forEach(n => n.audio.muted = to);
        } else if (player?.volumeSupported) {
            if (player.volume > 0) { savedVolume = player.volume; player.volume = 0; }
            else player.volume = savedVolume || 1;
        }
    }

    // ---- backdrop: blurred art, clipped to the rounded card
    Image {
        id: art
        anchors.fill: parent
        source: root.player?.trackArtUrl ?? ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 400
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: art
        visible: art.status === Image.Ready
        blurEnabled: true
        blur: 1
        blurMax: 48
        saturation: 0.2
        opacity: 0.45
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Tokens.space.m
        spacing: Tokens.space.m

        ClippingRectangle {
            Layout.preferredWidth: 104
            Layout.preferredHeight: 104
            Layout.alignment: Qt.AlignTop
            radius: Tokens.radius.l
            color: MediaPalette.container

            Image {
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 208
                asynchronous: true
            }
            Icon {
                anchors.centerIn: parent
                visible: !root.player?.trackArtUrl
                text: "music_note"
                size: 40
                color: root.fg
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    text: root.player?.identity ?? ""
                    font.pixelSize: Tokens.font.xs
                    color: Theme.alpha(root.fg, 0.7)
                }
                // Step through players and audio apps.
                IconButton {
                    visible: Media.sources.length > 1
                    size: 24; iconSize: 18
                    icon: "chevron_left"
                    content: root.fg
                    onClicked: Media.previousSource()
                }
                StyledText {
                    visible: Media.sources.length > 1
                    text: `${Media.index + 1}/${Media.sources.length}`
                    font.pixelSize: Tokens.font.xs
                    font.features: { "tnum": 1 }
                    color: Theme.alpha(root.fg, 0.7)
                }
                IconButton {
                    visible: Media.sources.length > 1
                    size: 24; iconSize: 18
                    icon: "chevron_right"
                    content: root.fg
                    onClicked: Media.nextSource()
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackTitle || "Unknown title"
                font.pixelSize: Tokens.font.l
                font.weight: Font.DemiBold
                color: root.fg
            }
            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackArtist ?? ""
                color: Theme.alpha(root.fg, 0.8)
            }

            Item { Layout.fillHeight: true }

            SeekBar {
                Layout.fillWidth: true
                implicitHeight: 18
                progress: root.length > 0 ? root.position / root.length : 0
                playing: root.player?.isPlaying ?? false
                seekable: (root.player?.canSeek ?? false) && root.length > 0
                color: root.accent
                track: MediaPalette.track
                onSeek: f => {
                    Media.seek(root.player, f * root.length);
                    root.position = f * root.length;
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 2
                StyledText {
                    text: root.length > 0 ? `${Media.fmt(root.position)} / ${Media.fmt(root.length)}` : Media.fmt(root.position)
                    font.pixelSize: Tokens.font.xs
                    font.features: { "tnum": 1 }
                    color: Theme.alpha(root.fg, 0.75)
                }
                Item { Layout.fillWidth: true }
                IconButton {
                    size: 30
                    icon: root.muted ? "volume_off" : "volume_up"
                    content: root.muted ? root.accent : root.fg
                    onClicked: root.toggleMute()
                }
                IconButton {
                    size: 30
                    icon: "skip_previous"
                    content: root.fg
                    enabled: root.player?.canGoPrevious ?? false
                    opacity: enabled ? 1 : 0.4
                    onClicked: root.player.previous()
                }
                IconButton {
                    size: 38
                    icon: root.player?.isPlaying ? "pause" : "play_arrow"
                    base: root.accent
                    content: root.accentFg
                    onClicked: root.player?.togglePlaying()
                }
                IconButton {
                    size: 30
                    icon: "skip_next"
                    content: root.fg
                    enabled: root.player?.canGoNext ?? false
                    opacity: enabled ? 1 : 0.4
                    onClicked: root.player.next()
                }
            }
        }
    }
}
