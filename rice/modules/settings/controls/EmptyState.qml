import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Centered illustration for empty lists, missing hardware and loading.
ColumnLayout {
    id: root

    property string icon: "info"
    property string title
    property string text
    property bool loading: false
    default property alias actions: act.data

    Layout.fillWidth: true
    Layout.topMargin: Tokens.space.l
    Layout.bottomMargin: Tokens.space.l
    spacing: Tokens.space.s

    Item {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 72
        implicitHeight: 72
        Rectangle {
            anchors.fill: parent
            radius: 26
            color: Theme.surfaceHigh
            rotation: root.loading ? 0 : 12
            visible: !root.loading
        }
        Icon {
            anchors.centerIn: parent
            visible: !root.loading
            text: root.icon
            size: 34
            color: Theme.primary
        }
        Spinner {
            anchors.centerIn: parent
            visible: root.loading
            size: 40
        }
    }
    StyledText {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.space.xs
        horizontalAlignment: Text.AlignHCenter
        text: root.title
        font.pixelSize: Tokens.font.l
        font.weight: Font.Medium
    }
    StyledText {
        Layout.fillWidth: true
        visible: text !== ""
        horizontalAlignment: Text.AlignHCenter
        text: root.text
        color: Theme.surfaceVariantFg
        wrapMode: Text.Wrap
    }
    RowLayout {
        id: act
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: children.length ? Tokens.space.s : 0
        spacing: Tokens.space.s
    }
}
