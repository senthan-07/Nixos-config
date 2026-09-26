import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Collapsed "now playing": art, title (or the current synced lyric line),
// an optional running-timer chip and live spectrum bars.
Item {
    id: root

    readonly property var player: Media.active
    readonly property bool showLyric: IslandState.compactLyrics && Lyrics.synced && Lyrics.currentLine !== ""
    readonly property string label: showLyric ? Lyrics.currentLine
        : [player?.trackTitle || "Unknown title", player?.trackArtist ?? ""].filter(s => s).join(" · ")

    implicitHeight: 40
    implicitWidth: row.implicitWidth + Tokens.space.xs * 2 + Tokens.space.m

    // Keep Lyrics polling the player position only while a line can be shown.
    readonly property bool wantsLyrics: IslandState.compactLyrics && visible
    onWantsLyricsChanged: wantsLyrics ? Lyrics.acquire() : Lyrics.release()
    Component.onDestruction: if (wantsLyrics) Lyrics.release()

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.leftMargin: Tokens.space.xs + 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.space.s

        ArtCover {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: 15
            iconSize: 16
            source: root.player?.trackArtUrl ?? ""
            placeholder: MediaPalette.container
            placeholderFg: MediaPalette.containerFg
        }

        // Title with a vertical slide when it changes.
        Item {
            id: titleBox
            Layout.preferredWidth: Math.min(260, measure.implicitWidth)
            Layout.preferredHeight: 20
            clip: true
            Behavior on Layout.preferredWidth { Anim { easing.bezierCurve: Motion.curve.emphasizedDecel } }

            StyledText { id: measure; visible: false; text: root.label; font.weight: Font.DemiBold }

            StyledText {
                id: title
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                font.weight: Font.DemiBold
                color: root.showLyric ? MediaPalette.accent : Theme.surfaceFg
            }
        }

        // Running pomodoro / stopwatch chip
        Rectangle {
            visible: IslandState.timerActive
            implicitHeight: 22
            implicitWidth: chipRow.implicitWidth + Tokens.space.m
            radius: 11
            color: Theme.alpha(Timers.pomodoroRunning ? (Timers.pomodoroPhase === "focus" ? Theme.primary : Theme.tertiary) : Theme.secondary, 0.18)
            Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: 3
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Timers.pomodoroRunning ? (Timers.pomodoroPhase === "focus" ? "target" : "local_cafe") : "timer"
                    size: 13
                    fill: 1
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Timers.pomodoroRunning ? Timers.fmt(Timers.pomodoroRemaining) : Timers.fmt(Timers.stopwatchElapsed)
                    font.pixelSize: Tokens.font.xs
                    font.features: { "tnum": 1 }
                    font.weight: Font.DemiBold
                }
            }
        }

        SpectrumBars {
            Layout.preferredHeight: 18
            Layout.rightMargin: Tokens.space.xs
            count: 5
            color: MediaPalette.accent
            running: root.visible && root.opacity > 0
        }
    }
}
