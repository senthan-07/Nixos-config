import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services
import qs.modules.notifications

// Hub "Notifications" tab: history with clear-all, newest first.
Item {
    id: root

    readonly property var items: [...Notifs.history].reverse()

    implicitWidth: 780
    implicitHeight: items.length ? Math.min(380, header.height + Tokens.space.s + list.implicitHeight) : 200

    RowLayout {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        visible: root.items.length > 0

        StyledText {
            Layout.fillWidth: true
            text: `${root.items.length} notification${root.items.length === 1 ? "" : "s"}`
            color: Theme.surfaceVariantFg
        }
        Surface {
            implicitWidth: clearLabel.implicitWidth + Tokens.space.l * 2
            implicitHeight: 30
            radius: height / 2
            interactive: true
            base: Theme.surfaceHigh
            onClicked: Notifs.clear()
            StyledText {
                id: clearLabel
                anchors.centerIn: parent
                text: "Clear all"
                font.weight: Font.Medium
            }
        }
    }

    Flickable {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.topMargin: Tokens.space.s
        anchors.bottom: parent.bottom
        visible: root.items.length > 0
        contentHeight: list.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: list
            width: parent.width
            spacing: Tokens.space.s

            Repeater {
                model: root.items
                NotificationCard {
                    required property var modelData
                    Layout.fillWidth: true
                    notification: modelData
                }
            }
        }
    }

    // Empty state
    ColumnLayout {
        anchors.centerIn: parent
        visible: root.items.length === 0
        spacing: Tokens.space.s

        Icon {
            Layout.alignment: Qt.AlignHCenter
            text: "notifications_paused"
            size: 40
            color: Theme.outline
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Notifs.dnd ? "All caught up · Do not disturb is on" : "All caught up"
            color: Theme.outline
        }
    }
}
