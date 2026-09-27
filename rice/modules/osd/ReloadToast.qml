import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components

// Replaces Quickshell's built-in reload popup with a themed toast:
// success is a short pill that fades out; a failed reload shows the error
// and stays until clicked.
Scope {
    id: root

    property bool shown: false
    property bool failed: false
    property string message: ""

    Connections {
        target: Quickshell
        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup();
            root.failed = false;
            root.message = "Shell reloaded";
            root.shown = true;
            hideTimer.restart();
        }
        function onReloadFailed(error) {
            Quickshell.inhibitReloadPopup();
            root.failed = true;
            root.message = String(error);
            root.shown = true;
            hideTimer.stop();
        }
    }

    Timer {
        id: hideTimer
        interval: 1800
        onTriggered: root.shown = false
    }

    PanelWindow {
        id: win
        screen: Quickshell.screens[0]
        visible: root.shown || card.opacity > 0
        anchors.top: true
        margins.top: Tokens.bar.height + Tokens.bar.gap + Tokens.space.s
        implicitWidth: Math.min(640, (screen?.width ?? 1920) - 64)
        implicitHeight: card.implicitHeight + 8
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.namespace: "rice-reload"
        WlrLayershell.layer: WlrLayer.Overlay
        // Success toast is click-through; the error card takes a click to dismiss.
        mask: Region { item: root.failed ? card : null }

        Rectangle {
            id: card
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.shown ? 0 : -12
            width: root.failed ? parent.width : row.implicitWidth + Tokens.space.l * 2
            implicitHeight: root.failed ? col.implicitHeight + Tokens.space.l * 2 : 40
            radius: root.failed ? Tokens.radius.l : height / 2
            color: root.failed ? Theme.errorContainer : Theme.inverseSurface
            opacity: root.shown ? 1 : 0
            Behavior on opacity { Anim { duration: Motion.duration.short } }
            Behavior on y { Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.emphasizedDecel } }

            // Success
            RowLayout {
                id: row
                visible: !root.failed
                anchors.centerIn: parent
                spacing: Tokens.space.s
                Icon { text: "check_circle"; size: 18; fill: 1; color: Theme.inversePrimary }
                StyledText { text: root.message; color: Theme.inverseOnSurface; font.weight: Font.Medium }
            }

            // Failure
            ColumnLayout {
                id: col
                visible: root.failed
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.space.l
                spacing: Tokens.space.xs
                RowLayout {
                    spacing: Tokens.space.s
                    Icon { text: "error"; size: 20; fill: 1; color: Theme.error }
                    StyledText {
                        Layout.fillWidth: true
                        text: "Reload failed — the previous config is still running"
                        font.weight: Font.DemiBold
                        color: Theme.errorContainerFg
                    }
                    StyledText { text: "click to dismiss"; font.pixelSize: Tokens.font.xs; color: Theme.alpha(Theme.errorContainerFg, 0.7) }
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.message
                    wrapMode: Text.Wrap
                    maximumLineCount: 6
                    elide: Text.ElideRight
                    font.family: Tokens.font.mono
                    font.pixelSize: Tokens.font.s
                    color: Theme.errorContainerFg
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.failed
                cursorShape: Qt.PointingHandCursor
                onClicked: root.shown = false
            }
        }
    }
}
