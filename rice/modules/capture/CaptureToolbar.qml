import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Floating toolbar of the region selector: selection mode, action, audio
// toggle, cancel and confirm.
Rectangle {
    id: root

    property bool canConfirm: false
    signal confirmRequested()
    signal cancelRequested()

    readonly property bool picking: Capture.action === "pick"
    readonly property bool recording: Capture.action === "record"

    implicitWidth: layout.implicitWidth + Tokens.space.s * 2
    implicitHeight: 56
    radius: height / 2
    color: Theme.surfaceContainer
    border.width: 1
    border.color: Theme.alpha(Theme.outlineVariant, 0.7)

    Behavior on implicitWidth { Anim { easing.bezierCurve: Motion.curve.springDefault } }

    // Soft drop shadow.
    Rectangle {
        z: -1
        anchors.fill: parent
        anchors.margins: -1
        anchors.topMargin: 3
        anchors.bottomMargin: -5
        radius: height / 2
        color: Theme.alpha(Theme.shadow, 0.28)
    }

    // Eat clicks so they don't reach the selection area underneath.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Tokens.space.s

        ToolGroup {
            visible: !root.picking
            current: Capture.mode
            model: [
                { id: "region", icon: "crop_free", label: "Region", key: "R" },
                { id: "window", icon: "web_asset", label: "Window", key: "W", enabled: Capture.windows.length > 0 || !Capture.windowsLoaded },
                { id: "screen", icon: "desktop_windows", label: "Screen", key: "S" }
            ]
            onPicked: id => Capture.setMode(id)
        }

        Rectangle {
            visible: !root.picking
            implicitWidth: 1
            implicitHeight: 24
            color: Theme.outlineVariant
        }

        ToolGroup {
            current: Capture.action
            accent: root.recording ? Theme.errorContainer : Theme.primaryContainer
            accentFg: root.recording ? Theme.errorContainerFg : Theme.primaryContainerFg
            model: [
                { id: "screenshot", icon: "screenshot_region", label: "Screenshot", key: "C" },
                { id: "ocr", icon: "document_scanner", label: "Text", key: "T", enabled: !Capture.toolsLoaded || Capture.has("tesseract") },
                { id: "record", icon: "videocam", label: "Record", key: "V", enabled: !Capture.toolsLoaded || Capture.has("wf-recorder") || Capture.has("gpu-screen-recorder") },
                { id: "pick", icon: "colorize", label: "Colour", key: "P" }
            ]
            onPicked: id => Capture.setAction(id)
        }

        IconButton {
            visible: root.recording
            size: 40
            icon: Capture.recordAudio ? "volume_up" : "volume_off"
            toggled: Capture.recordAudio
            onClicked: Capture.setAudio(!Capture.recordAudio)

            ToolTipBubble {
                shown: parent.hovered
                text: Capture.recordAudio ? "Recording system audio  ·  A" : "No audio  ·  A"
            }
        }

        Rectangle {
            implicitWidth: 1
            implicitHeight: 24
            color: Theme.outlineVariant
        }

        IconButton {
            size: 40
            icon: "close"
            onClicked: root.cancelRequested()

            ToolTipBubble {
                shown: parent.hovered
                text: "Cancel  ·  Esc"
            }
        }

        // Confirm: an expressive FAB-style pill.
        Surface {
            id: confirm
            visible: !root.picking
            implicitHeight: 40
            implicitWidth: confirmRow.implicitWidth + Tokens.space.l * 2
            radius: root.canConfirm ? Tokens.radius.m : height / 2
            interactive: root.canConfirm
            opacity: root.canConfirm ? 1 : 0.45
            base: root.recording ? Theme.error : Theme.primary
            content: root.recording ? Theme.errorFg : Theme.primaryFg
            onClicked: root.confirmRequested()

            Behavior on radius { Anim { duration: Motion.duration.short } }
            Behavior on opacity { Anim { duration: Motion.duration.short } }

            RowLayout {
                id: confirmRow
                anchors.centerIn: parent
                spacing: Tokens.space.s

                Icon {
                    text: root.recording ? "radio_button_checked" : Capture.action === "ocr" ? "content_copy" : "check"
                    size: 20
                    fill: 1
                    color: confirm.content
                }
                StyledText {
                    text: root.recording ? "Record" : Capture.action === "ocr" ? "Copy text" : "Capture"
                    font.weight: Font.DemiBold
                    color: confirm.content
                }
            }

            ToolTipBubble {
                shown: confirm.hovered
                text: "Enter"
            }
        }
    }
}
