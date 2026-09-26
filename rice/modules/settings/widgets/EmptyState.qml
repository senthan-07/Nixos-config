import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Centered icon + title + body used for empty, loading and error states.
//   EmptyState { icon: "wallpaper"; title: "No wallpapers"; body: "…"; busy: false }
ColumnLayout {
    id: root

    property string icon: "info"
    property string title
    property string body
    property bool busy: false
    property color accent: Theme.primary
    default property alias actions: actionRow.data

    Layout.fillWidth: true
    spacing: Tokens.space.s

    Item {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Tokens.space.l
        implicitWidth: 72
        implicitHeight: 72

        Rectangle {
            id: blob
            anchors.fill: parent
            radius: root.busy ? width / 2 : Tokens.radius.xl
            color: Theme.alpha(root.accent, 0.14)
            Behavior on radius { Anim {} }
            RotationAnimation on rotation {
                running: root.busy
                loops: Animation.Infinite
                from: 0; to: 360
                duration: 2400
            }
        }

        // Indeterminate arc while busy.
        Canvas {
            id: arc
            anchors.fill: parent
            visible: root.busy
            property real start: 0
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.lineWidth = 4;
                ctx.lineCap = "round";
                ctx.strokeStyle = root.accent;
                ctx.beginPath();
                ctx.arc(width / 2, height / 2, width / 2 - 3, start, start + Math.PI * 1.2);
                ctx.stroke();
            }
            NumberAnimation on start {
                running: root.busy
                loops: Animation.Infinite
                from: 0; to: Math.PI * 2
                duration: 1100
            }
            onStartChanged: requestPaint()
        }

        Icon {
            anchors.centerIn: parent
            text: root.icon
            size: 34
            fill: 1
            color: root.accent
        }
    }

    StyledText {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        visible: text !== ""
        text: root.title
        font.pixelSize: Tokens.font.l
        font.weight: Font.DemiBold
    }

    StyledText {
        Layout.fillWidth: true
        Layout.maximumWidth: 460
        Layout.alignment: Qt.AlignHCenter
        horizontalAlignment: Text.AlignHCenter
        visible: text !== ""
        text: root.body
        color: Theme.surfaceVariantFg
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }

    RowLayout {
        id: actionRow
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: children.length ? Tokens.space.s : 0
        Layout.bottomMargin: Tokens.space.l
        spacing: Tokens.space.s
    }
}
