import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services
import qs.modules.notifications

ColumnLayout {
    Layout.fillWidth: true
    Layout.preferredWidth: parent ? parent.width : implicitWidth
    spacing: Tokens.space.s

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.space.s

        StyledText {
            Layout.fillWidth: true
            text: Notifs.history.length ? `Notifications  ·  ${Notifs.history.length}` : "Notifications"
            font.pixelSize: Tokens.font.l
            font.weight: Font.DemiBold
        }
        Surface {
            visible: Notifs.history.length > 0
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

    Repeater {
        model: [...Notifs.history].reverse()

        NotificationCard {
            required property var modelData
            Layout.fillWidth: true
            notification: modelData
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.space.xl
        Layout.bottomMargin: Tokens.space.xl
        visible: Notifs.history.length === 0
        spacing: Tokens.space.s

        // fillWidth + centred text, so they centre even if this column's
        // width comes from its contents.
        Icon {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "notifications_paused"
            size: 40
            color: Theme.outline
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "All caught up"
            color: Theme.outline
        }
    }
}
