import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Titled card grouping SettingsRows.
ColumnLayout {
    id: root

    property string title
    default property alias content: card.data

    Layout.fillWidth: true
    spacing: Tokens.space.s

    StyledText {
        visible: root.title !== ""
        text: root.title
        color: Theme.primary
        font.weight: Font.DemiBold
        Layout.leftMargin: Tokens.space.s
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: card.implicitHeight + Tokens.space.s * 2
        radius: Tokens.radius.l
        color: Theme.surfaceContainer

        ColumnLayout {
            id: card
            x: Tokens.space.s
            y: Tokens.space.s
            width: parent.width - Tokens.space.s * 2
            spacing: 2
        }
    }
}
