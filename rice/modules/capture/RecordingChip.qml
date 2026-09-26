import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Bar chip shown while a recording is running: pulsing dot, elapsed time and
// a stop button. Click stops (and saves); right click opens the folder.
Chip {
    id: root

    readonly property bool live: Recording.active || Recording.state === "error"
    readonly property bool starting: Recording.state === "starting"
    readonly property bool stopping: Recording.state === "stopping"
    readonly property bool failed: Recording.state === "error"

    visible: live || opacity > 0.01
    opacity: live ? 1 : 0
    scale: live ? 1 : 0.85
    interactive: Recording.isRecording || failed
    padding: Tokens.space.s + 2
    spacing: Tokens.space.s
    base: failed ? Theme.error : Theme.errorContainer
    readonly property color fg: failed ? Theme.errorFg : Theme.errorContainerFg
    onClicked: m => {
        if (m.button === Qt.RightButton)
            Qt.openUrlExternally(`file://${Capture.recordingDir}`);
        else if (Recording.isRecording)
            Recording.stop();
    }

    Behavior on opacity { Anim { duration: Motion.duration.short } }
    Behavior on scale { Anim { easing.bezierCurve: Motion.curve.springFast } }

    // Pulsing record dot (or a source icon for audio-only recordings).
    Item {
        implicitWidth: 14
        implicitHeight: 14

        Rectangle {
            id: halo
            anchors.centerIn: parent
            width: 14
            height: 14
            radius: 7
            color: Theme.error
            opacity: 0
            visible: Recording.kind === "screen" && Recording.isRecording
            SequentialAnimation on scale {
                running: halo.visible
                loops: Animation.Infinite
                NumberAnimation { from: 0.6; to: 1.6; duration: 1100; easing.type: Easing.OutCubic }
            }
            SequentialAnimation on opacity {
                running: halo.visible
                loops: Animation.Infinite
                NumberAnimation { from: 0.5; to: 0; duration: 1100; easing.type: Easing.OutCubic }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            visible: Recording.kind === "screen" && !root.failed
            width: root.starting || root.stopping ? 8 : 10
            height: width
            radius: root.stopping ? 2 : width / 2
            color: Theme.error
            opacity: root.starting ? 0.5 : 1
            Behavior on width { Anim { duration: Motion.duration.short } }
            Behavior on radius { Anim { duration: Motion.duration.short } }
        }

        Icon {
            anchors.centerIn: parent
            visible: Recording.kind === "audio" || root.failed
            text: root.failed ? "error" : Recording.source === "mic" ? "mic" : "graphic_eq"
            size: 16
            fill: 1
            color: root.failed ? root.fg : Theme.error
        }
    }

    StyledText {
        text: root.failed ? "Recording failed" : root.starting ? "Starting…" : root.stopping ? "Saving…" : Recording.elapsedText
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
        color: root.fg
    }

    Icon {
        visible: Recording.withAudio && Recording.kind === "screen" && !root.failed
        text: "volume_up"
        size: 15
        color: Theme.alpha(root.fg, 0.8)
    }

    // Stop button.
    Rectangle {
        visible: Recording.isRecording
        implicitWidth: 20
        implicitHeight: 20
        radius: root.hovered ? 6 : 10
        color: root.hovered ? Theme.error : Theme.alpha(Theme.error, 0.18)
        Behavior on radius { Anim { duration: Motion.duration.short } }
        Behavior on color { ColorAnim {} }

        Rectangle {
            anchors.centerIn: parent
            width: 8
            height: 8
            radius: 2
            color: root.hovered ? Theme.errorFg : Theme.error
        }
    }
}
