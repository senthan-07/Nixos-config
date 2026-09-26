import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// One row: icon, label + description, and a trailing control (put it as a child).
//   SettingsRow { icon: "wifi"; label: "Wi-Fi"; description: "…"; SettingsSwitch { … } }
Surface {
    id: root

    property string icon
    property string label
    property string description
    default property alias trailing: trail.data

    Layout.fillWidth: true
    implicitHeight: Math.max(56, row.implicitHeight + Tokens.space.m * 2)
    radius: Tokens.radius.m
    base: Theme.surfaceContainer

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: Tokens.space.l
        anchors.rightMargin: Tokens.space.l
        spacing: Tokens.space.l

        Icon {
            visible: root.icon !== ""
            text: root.icon
            size: 22
            color: Theme.surfaceVariantFg
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            StyledText {
                Layout.fillWidth: true
                text: root.label
                font.weight: Font.Medium
            }
            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.description
                font.pixelSize: Tokens.font.s
                color: Theme.surfaceVariantFg
                wrapMode: Text.Wrap
            }
        }

        RowLayout {
            id: trail
            spacing: Tokens.space.s
        }
    }
}
