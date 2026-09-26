import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Back button + title for page-internal sub views (e.g. Network › Saved networks).
RowLayout {
    id: root

    property string title
    property string parentTitle
    signal back()

    Layout.fillWidth: true
    spacing: Tokens.space.s

    IconButton {
        icon: "arrow_back"
        size: 40
        filled: true
        onClicked: root.back()
    }
    StyledText {
        visible: root.parentTitle !== ""
        text: root.parentTitle
        color: Theme.surfaceVariantFg
    }
    Icon {
        visible: root.parentTitle !== ""
        text: "chevron_right"
        size: 18
        color: Theme.surfaceVariantFg
    }
    StyledText {
        Layout.fillWidth: true
        text: root.title
        font.pixelSize: Tokens.font.l
        font.weight: Font.DemiBold
    }
}
