import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// One window in the hover preview: live thumbnail, title and close button.
Surface {
    id: root

    required property var toplevel
    property string appKey
    property bool live: true
    property bool thumbnails: true
    property bool selected: false

    readonly property string title: toplevel ? (toplevel.title || Dock.nameFor(appKey)) : ""
    readonly property real thumbHeight: thumbnails ? (width - Tokens.space.s * 2) / 1.6 : 0

    signal picked()
    signal closeRequested()

    implicitWidth: 220
    implicitHeight: 36 + (thumbnails ? thumbHeight + Tokens.space.s : 0)
    radius: Tokens.radius.m
    interactive: true
    base: selected ? Theme.secondaryContainer : Theme.alpha(Theme.surfaceContainer, 0)
    content: selected ? Theme.secondaryContainerFg : Theme.surfaceFg
    border.width: toplevel && toplevel.activated ? 1 : 0
    border.color: Theme.alpha(Theme.primary, 0.6)

    onClicked: m => m.button === Qt.MiddleButton ? root.closeRequested() : root.picked()

    RowLayout {
        id: header
        x: Tokens.space.s
        width: parent.width - Tokens.space.s * 2 + 2
        height: 36
        spacing: Tokens.space.s

        AppIcon {
            size: 18
            name: Dock.iconFor(root.appKey)
        }
        StyledText {
            Layout.fillWidth: true
            text: root.title
            font.pixelSize: Tokens.font.s
            font.weight: root.toplevel && root.toplevel.activated ? Font.DemiBold : Font.Normal
            color: root.content
        }
        IconButton {
            size: 26
            icon: "close"
            iconSize: 16
            opacity: root.hovered || hovered || root.selected ? 1 : 0
            base: hovered ? Theme.errorContainer : Theme.alpha(Theme.surface, 0)
            content: hovered ? Theme.errorContainerFg : Theme.surfaceVariantFg
            Behavior on opacity { Anim { duration: Motion.duration.tiny } }
            onClicked: root.closeRequested()
        }
    }

    Rectangle {
        id: frame
        visible: root.thumbnails
        x: Tokens.space.s
        y: header.height
        width: parent.width - Tokens.space.s * 2
        height: root.thumbHeight
        radius: Tokens.radius.s
        color: Theme.surfaceHighest
        clip: true

        ScreencopyView {
            id: view
            // Fit the capture into the frame, preserving the window's aspect ratio.
            readonly property real aspect: sourceSize.width > 0 && sourceSize.height > 0 ? sourceSize.width / sourceSize.height : 1.6
            readonly property bool wide: aspect >= frame.width / frame.height
            anchors.centerIn: parent
            width: wide ? frame.width : frame.height * aspect
            height: wide ? frame.width / aspect : frame.height
            captureSource: root.thumbnails && root.live ? root.toplevel : null
            live: root.live
            paintCursor: false
            constraintSize: Qt.size(frame.width * 2, frame.height * 2)
            opacity: hasContent ? 1 : 0
            Behavior on opacity { Anim { duration: Motion.duration.short } }
        }

        // Loading, then a graceful fallback when the compositor can't capture.
        property bool timedOut: false
        Timer {
            running: root.thumbnails && !view.hasContent
            interval: 1600
            onTriggered: frame.timedOut = true
        }

        Item {
            anchors.fill: parent
            visible: !view.hasContent && frame.timedOut
            ColumnLayout {
                anchors.centerIn: parent
                spacing: Tokens.space.xs
                AppIcon {
                    Layout.alignment: Qt.AlignHCenter
                    size: Math.min(48, frame.height * 0.4)
                    name: Dock.iconFor(root.appKey)
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.toplevel && root.toplevel.minimized ? "Minimized" : "No preview"
                    font.pixelSize: Tokens.font.xs
                    color: Theme.surfaceVariantFg
                }
            }
        }

        // Indeterminate spinner while waiting for the first frame.
        Rectangle {
            id: spinner
            property real angle: 0
            anchors.centerIn: parent
            visible: !view.hasContent && !frame.timedOut
            width: 22
            height: 22
            radius: 11
            color: "transparent"
            border.width: 3
            border.color: Theme.alpha(Theme.primary, 0.25)
            NumberAnimation on angle { from: 0; to: Math.PI * 2; duration: 900; loops: Animation.Infinite; running: spinner.visible }
            Rectangle {
                width: 6; height: 6; radius: 3
                color: Theme.primary
                x: 8 + 8 * Math.cos(spinner.angle); y: 8 + 8 * Math.sin(spinner.angle)
            }
        }
    }
}
