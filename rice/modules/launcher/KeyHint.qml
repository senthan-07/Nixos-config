import QtQuick
import qs.config
import qs.components

// Keycap + label, e.g. [↵] Open
Row {
    id: root

    property string keys
    property string label
    property color fg: Theme.surfaceVariantFg
    property color cap: Theme.alpha(Theme.surfaceFg, 0.08)

    spacing: 6

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(22, keyText.implicitWidth + 12)
        height: 22
        radius: 7
        color: root.cap

        StyledText {
            id: keyText
            anchors.centerIn: parent
            text: root.keys
            font.pixelSize: Tokens.font.xs + 1
            font.weight: Font.DemiBold
            color: root.fg
        }
    }

    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.label !== ""
        text: root.label
        font.pixelSize: Tokens.font.s
        color: root.fg
    }
}
