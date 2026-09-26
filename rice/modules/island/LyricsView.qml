import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Scrolling synced lyrics: the current line is centred-ish and emphasised,
// past lines dim, future lines muted. Click a line to seek there.
Item {
    id: root

    property color accent: Theme.primary
    property color textColor: Theme.surfaceFg
    property bool active: visible

    onActiveChanged: active ? Lyrics.acquire() : Lyrics.release()
    Component.onCompleted: if (active) Lyrics.acquire()
    Component.onDestruction: if (active) Lyrics.release()

    readonly property bool hasLines: Lyrics.status === "ready" && Lyrics.lines.length > 0

    ListView {
        id: list
        anchors.fill: parent
        visible: root.hasLines
        clip: true
        model: root.hasLines ? Lyrics.lines : []
        spacing: Tokens.space.xs
        interactive: !Lyrics.synced || !(Lyrics.player?.isPlaying ?? false)
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: Lyrics.synced ? Math.max(0, Lyrics.index) : -1
        highlightFollowsCurrentItem: true
        highlightRangeMode: Lyrics.synced ? ListView.ApplyRange : ListView.NoHighlightRange
        preferredHighlightBegin: height * 0.34
        preferredHighlightEnd: height * 0.34 + 36
        highlightMoveDuration: Motion.duration.long
        highlightMoveVelocity: -1
        highlight: Item {}

        header: Item { height: Lyrics.synced ? list.height * 0.34 : 0; width: 1 }
        footer: Item { height: Lyrics.synced ? list.height * 0.6 : Tokens.space.s; width: 1 }

        delegate: Item {
            id: line
            required property var modelData
            required property int index
            readonly property bool current: Lyrics.synced && index === Lyrics.index
            readonly property bool past: Lyrics.synced && index < Lyrics.index

            width: ListView.view.width
            height: label.implicitHeight + Tokens.space.xs * 2

            StyledText {
                id: label
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: line.modelData.text || "♪"
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                maximumLineCount: 3
                font.pixelSize: Tokens.font.l
                font.weight: line.current ? Font.Bold : Font.Medium
                color: line.current ? root.accent : root.textColor
                opacity: !Lyrics.synced ? 0.9 : line.current ? 1 : line.past ? 0.32 : 0.55
                transformOrigin: Item.Left
                scale: line.current || !Lyrics.synced ? 1 : 0.94
                Behavior on opacity { Anim { duration: Motion.duration.medium } }
                Behavior on scale { Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.springDefault } }
            }

            MouseArea {
                anchors.fill: parent
                enabled: Lyrics.synced && (Lyrics.player?.canSeek ?? false)
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    Media.seek(Lyrics.player, Math.max(0, line.modelData.time - Lyrics.offset));
                    Lyrics.syncPosition();
                }
            }
        }
    }

    // Soft fade at the top and bottom edges.
    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 28
        visible: list.visible && Lyrics.synced
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.alpha(root.fadeColor, 1) }
            GradientStop { position: 1; color: Theme.alpha(root.fadeColor, 0) }
        }
    }
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 36
        visible: list.visible
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.alpha(root.fadeColor, 0) }
            GradientStop { position: 1; color: Theme.alpha(root.fadeColor, 1) }
        }
    }
    property color fadeColor: Theme.surfaceContainer

    // Empty / loading / error states.
    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - Tokens.space.l * 2
        visible: !root.hasLines
        spacing: Tokens.space.s

        Icon {
            Layout.alignment: Qt.AlignHCenter
            text: Lyrics.status === "loading" ? "lyrics"
                : Lyrics.status === "error" ? "cloud_off"
                : Lyrics.instrumental ? "piano" : "subtitles_off"
            size: 30
            color: root.textColor
            opacity: 0.6

            SequentialAnimation on opacity {
                running: Lyrics.status === "loading" && root.visible
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.6; duration: 700; easing.type: Easing.InOutSine }
            }
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: root.textColor
            opacity: 0.75
            text: Lyrics.status === "loading" ? "Finding lyrics…"
                : Lyrics.status === "error" ? Lyrics.error
                : Lyrics.instrumental ? "Instrumental"
                : Lyrics.status === "idle" ? "Lyrics appear here"
                : "No lyrics for this track"
        }

        Surface {
            Layout.alignment: Qt.AlignHCenter
            visible: Lyrics.status === "error"
            implicitWidth: retryRow.implicitWidth + Tokens.space.l * 2
            implicitHeight: 30
            radius: height / 2
            interactive: true
            base: Theme.alpha(root.accent, 0.18)
            content: root.textColor
            onClicked: Lyrics.retry()

            Row {
                id: retryRow
                anchors.centerIn: parent
                spacing: Tokens.space.xs
                Icon { text: "refresh"; size: 16; color: root.textColor; anchors.verticalCenter: parent.verticalCenter }
                StyledText { text: "Retry"; color: root.textColor; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    // "Not synced" badge for plain lyrics.
    Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: root.hasLines && !Lyrics.synced
        implicitWidth: badge.implicitWidth + Tokens.space.m
        implicitHeight: 20
        radius: 10
        color: Theme.alpha(root.textColor, 0.12)
        StyledText {
            id: badge
            anchors.centerIn: parent
            text: "Not synced"
            font.pixelSize: Tokens.font.xs
            color: root.textColor
            opacity: 0.8
        }
    }
}
