import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Small section heading in the sidebar's Wi-Fi / Bluetooth lists.
StyledText {
    Layout.fillWidth: true
    Layout.topMargin: Tokens.space.s
    Layout.leftMargin: Tokens.space.s
    font.pixelSize: Tokens.font.s
    font.weight: Font.DemiBold
    color: Theme.primary
}
