import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Base for every settings page: a scrolling column with a large title.
//   SettingsPage { title: "Network"; SettingsSection { ... } }
Flickable {
    id: root

    property string title
    property string subtitle
    default property alias content: column.data

    contentWidth: width
    contentHeight: column.implicitHeight + Tokens.space.xxl * 2
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    ColumnLayout {
        id: column
        x: Tokens.space.xxl
        y: Tokens.space.xxl
        width: root.width - Tokens.space.xxl * 2
        spacing: Tokens.space.l

        StyledText {
            Layout.fillWidth: true
            text: root.title
            font.pixelSize: Tokens.font.xxl + 4
            font.weight: Font.DemiBold
        }
        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: -Tokens.space.s
            visible: text !== ""
            text: root.subtitle
            color: Theme.surfaceVariantFg
            wrapMode: Text.Wrap
        }
    }
}
