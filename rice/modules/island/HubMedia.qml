import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.config
import qs.components
import qs.services

// Hub "Media" tab: large art, track info, wavy seek bar, transport controls
// and a player switcher, all tinted with colours taken from the album art.
Item {
    id: root

    // The source picked with ◀ ▶ (a media player, or an app that only plays audio).
    readonly property var src: Media.current
    readonly property MprisPlayer player: src?.player ?? null
    readonly property bool hasPlayer: player !== null
    // Per-stream view: always for apps without media controls, on demand for players.
    property bool showStreams: false
    readonly property bool streamsView: src !== null && (!hasPlayer || showStreams)
    onSrcChanged: if (!src || src.key !== lastKey) { showStreams = false; lastKey = src?.key ?? ""; }
    property string lastKey: ""
    readonly property color accent: MediaPalette.accent
    readonly property color accentFg: MediaPalette.accentFg
    readonly property color fg: Theme.surfaceFg
    property color backdrop: MediaPalette.surface

    property real position: player?.position ?? 0
    // Firefox/Zen drop mpris:length after a seek until playback is toggled, which
    // made the bar jump to the end. Keep the last good length per track.
    // Updated imperatively (not a binding) to avoid a binding loop.
    readonly property string trackKey: player ? `${player.dbusName}|${player.trackTitle}|${player.trackArtist}` : ""
    readonly property real rawLength: player && player.length > 0 && isFinite(player.length) ? player.length : 0
    property real length: 0
    property string lengthKey: ""
    function updateLength() {
        const raw = rawLength;
        if (trackKey !== lengthKey) {
            lengthKey = trackKey;
            length = raw;
        } else if (raw > 0 && raw >= position) {
            length = raw;           // a trustworthy value
        } else if (length <= 0) {
            length = raw;
        }
    }
    onRawLengthChanged: updateLength()
    onTrackKeyChanged: updateLength()
    Component.onCompleted: updateLength()

    // Mute: the source's audio streams (works for browsers too); otherwise the
    // player's own volume.
    readonly property var muteStreams: (src?.streams ?? []).filter(n => n.audio)
    property real savedVolume: 1
    readonly property bool muted: muteStreams.length ? muteStreams.every(n => n.audio.muted)
        : (player?.volumeSupported ?? false) && player.volume === 0
    readonly property bool canMute: muteStreams.length > 0 || (player?.volumeSupported ?? false)
    function toggleMute() {
        if (muteStreams.length) {
            const to = !muted;
            muteStreams.forEach(n => n.audio.muted = to);
        } else if (player?.volumeSupported) {
            if (player.volume > 0) { savedVolume = player.volume; player.volume = 0; }
            else player.volume = savedVolume || 1;
        }
    }

    implicitWidth: 780
    implicitHeight: 256

    function seekBy(delta) {
        if (!player?.canSeek) return;
        Media.seek(player, Math.min(length || 1e9, player.position + delta));
        position = player.position;
    }

    Timer {
        running: root.visible && (root.player?.isPlaying ?? false)
        interval: 250
        repeat: true
        triggeredOnStart: true
        onTriggered: root.position = root.player?.position ?? 0
    }
    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPositionChanged() { root.position = root.player.position; }
        function onPostTrackChanged() { root.position = root.player.position; }
    }

    // ---- Empty state ----
    ColumnLayout {
        anchors.centerIn: parent
        visible: root.src === null
        spacing: Tokens.space.s

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 64
            implicitHeight: 64
            radius: Tokens.radius.l
            color: Theme.secondaryContainer
            Icon {
                anchors.centerIn: parent
                text: "music_off"
                size: 30
                color: Theme.secondaryContainerFg
            }
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: "Nothing playing"
            font.pixelSize: Tokens.font.xl
            font.weight: Font.DemiBold
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: "Start playback in any MPRIS-capable player"
            color: Theme.surfaceVariantFg
        }
    }

    MediaStreams {
        anchors.fill: parent
        anchors.leftMargin: root.edge
        anchors.rightMargin: root.edge
        visible: root.streamsView
        source: root.src
        showBack: root.hasPlayer
        onBack: root.showStreams = false
    }

    // ◀ ▶ on the card's edges step through every player and app playing audio;
    // dots at the bottom show where you are.
    readonly property bool multi: Media.sources.length > 1
    readonly property int edge: multi ? 44 : 0

    // Tinted with the album-art palette like the rest of the card.
    component EdgeArrow: IconButton {
        z: 10
        anchors.verticalCenter: parent.verticalCenter
        visible: root.multi
        size: 36
        iconSize: 24
        base: Theme.alpha(MediaPalette.container, 0.9)
        content: MediaPalette.containerFg
    }
    EdgeArrow { anchors.left: parent.left; icon: "chevron_left"; onClicked: Media.previousSource() }
    EdgeArrow { anchors.right: parent.right; icon: "chevron_right"; onClicked: Media.nextSource() }

    Row {
        z: 10
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -Tokens.space.m
        spacing: 6
        visible: root.multi
        Repeater {
            model: Media.sources.length
            Rectangle {
                required property int index
                width: index === Media.index ? 18 : 6
                height: 6
                radius: 3
                color: index === Media.index ? root.accent : Theme.alpha(MediaPalette.containerFg, 0.35)
                Behavior on width { Anim { duration: Motion.duration.short } }
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.edge
        anchors.rightMargin: root.edge
        visible: root.hasPlayer && !root.showStreams
        spacing: Tokens.space.xl

        ArtCover {
            Layout.preferredWidth: 216
            Layout.preferredHeight: 216
            Layout.alignment: Qt.AlignVCenter
            radius: Tokens.radius.xl
            source: root.player?.trackArtUrl ?? ""
            placeholder: MediaPalette.container
            placeholderFg: MediaPalette.containerFg

            // Player switcher badge
            Surface {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: Tokens.space.s
                implicitWidth: idRow.implicitWidth + Tokens.space.m * 2
                implicitHeight: 26
                radius: 13
                base: Theme.alpha(MediaPalette.container, 0.88)
                content: MediaPalette.containerFg

                Row {
                    id: idRow
                    anchors.centerIn: parent
                    spacing: Tokens.space.xs
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.player?.identity ?? ""
                        font.pixelSize: Tokens.font.xs
                        font.weight: Font.DemiBold
                        color: MediaPalette.containerFg
                    }
                }
            }

            // Several tabs/streams behind one player (e.g. browser tabs).
            Surface {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Tokens.space.s
                visible: (root.src?.streams.length ?? 0) > 1
                implicitWidth: streamRow.implicitWidth + Tokens.space.m * 2
                implicitHeight: 28
                radius: 14
                interactive: true
                base: Theme.alpha(MediaPalette.container, 0.92)
                content: MediaPalette.containerFg
                onClicked: root.showStreams = true

                Row {
                    id: streamRow
                    anchors.centerIn: parent
                    spacing: Tokens.space.xs
                    Icon { anchors.verticalCenter: parent.verticalCenter; text: "graphic_eq"; size: 14; color: MediaPalette.containerFg }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${root.src?.streams.length ?? 0} audio streams`
                        font.pixelSize: Tokens.font.xs
                        font.weight: Font.DemiBold
                        color: MediaPalette.containerFg
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.space.s
                text: root.player?.trackTitle || "Unknown title"
                font.pixelSize: Tokens.font.xxl - 2
                font.weight: Font.Bold
                maximumLineCount: 2
                wrapMode: Text.Wrap
            }
            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackArtist || "Unknown artist"
                font.pixelSize: Tokens.font.l
                color: root.accent
                font.weight: Font.Medium
            }
            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.player?.trackAlbum ?? ""
                color: Theme.surfaceVariantFg
                font.pixelSize: Tokens.font.s
            }

            Item { Layout.fillHeight: true }

            SeekBar {
                Layout.fillWidth: true
                progress: root.length > 0 ? root.position / root.length : 0
                playing: root.player?.isPlaying ?? false
                seekable: (root.player?.canSeek ?? false) && root.length > 0
                color: root.accent
                track: MediaPalette.track
                onSeek: f => {
                    Media.seek(root.player, f * root.length);
                    root.position = root.player.position;
                }
            }

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    text: Media.fmt(root.position)
                    font.pixelSize: Tokens.font.xs
                    font.features: { "tnum": 1 }
                    color: Theme.surfaceVariantFg
                }
                Item { Layout.fillWidth: true }
                StyledText {
                    text: root.length > 0 ? `-${Media.fmt(root.length - root.position)}` : "--:--"
                    font.pixelSize: Tokens.font.xs
                    font.features: { "tnum": 1 }
                    color: Theme.surfaceVariantFg
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.space.xs
                spacing: Tokens.space.xs

                IconButton {
                    icon: "shuffle"
                    size: 36
                    enabled: root.player?.shuffleSupported ?? false
                    opacity: enabled ? 1 : 0.35
                    content: root.player?.shuffle ? root.accent : Theme.surfaceVariantFg
                    onClicked: root.player.shuffle = !root.player.shuffle
                }
                Item { Layout.fillWidth: true }
                IconButton {
                    icon: "skip_previous"
                    iconSize: 26
                    size: 44
                    enabled: root.player?.canGoPrevious ?? false
                    opacity: enabled ? 1 : 0.35
                    content: root.fg
                    onClicked: root.player.previous()
                }

                // Morphing play/pause: circle when paused, squircle while playing.
                Surface {
                    id: play
                    readonly property bool playing: root.player?.isPlaying ?? false
                    implicitWidth: 68
                    implicitHeight: 52
                    radius: playing ? Tokens.radius.m : height / 2
                    interactive: true
                    base: root.accent
                    content: root.accentFg
                    onClicked: root.player.togglePlaying()
                    scale: pressed ? 0.94 : 1
                    Behavior on radius { Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.springDefault } }
                    Behavior on scale { Anim { duration: Motion.duration.short } }

                    Icon {
                        anchors.centerIn: parent
                        text: play.playing ? "pause" : "play_arrow"
                        size: 30
                        fill: 1
                        color: root.accentFg
                    }
                }

                IconButton {
                    icon: "skip_next"
                    iconSize: 26
                    size: 44
                    enabled: root.player?.canGoNext ?? false
                    opacity: enabled ? 1 : 0.35
                    content: root.fg
                    onClicked: root.player.next()
                }
                Item { Layout.fillWidth: true }
                IconButton {
                    readonly property int loop: root.player?.loopState ?? MprisLoopState.None
                    icon: loop === MprisLoopState.Track ? "repeat_one" : "repeat"
                    size: 36
                    enabled: root.player?.loopSupported ?? false
                    opacity: enabled ? 1 : 0.35
                    content: loop !== MprisLoopState.None ? root.accent : Theme.surfaceVariantFg
                    onClicked: root.player.loopState = loop === MprisLoopState.None ? MprisLoopState.Playlist
                        : loop === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
                }
                IconButton {
                    icon: root.muted ? "volume_off" : "volume_up"
                    size: 36
                    enabled: root.canMute
                    opacity: enabled ? 1 : 0.35
                    content: root.muted ? root.accent : Theme.surfaceVariantFg
                    onClicked: root.toggleMute()
                }
            }
        }

    }
}
