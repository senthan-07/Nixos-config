import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.config
import qs.components

// Container for the "framed" cards: rounded surface, optional drop shadow
// and a header row (icon, title, trailing items). Children go below it.
//   CardFrame { icon: "hard_drive"; title: "Storage"; Item {...} }
Item {
    id: root

    property string icon
    property string title
    property string subtitle
    property bool elevated: true
    property color color: Theme.surfaceContainer
    property int padding: width < 220 ? Tokens.space.m : Tokens.space.l
    default property alias content: body.data
    property alias trailing: trail.data

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Tokens.radius.xl
        color: root.color
        Behavior on color { ColorAnim {} }
        layer.enabled: root.elevated
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.alpha(Theme.shadow, 0.35)
            shadowBlur: 0.7
            shadowVerticalOffset: 3
            autoPaddingEnabled: true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: Tokens.space.s

        RowLayout {
            Layout.fillWidth: true
            visible: root.title !== ""
            spacing: Tokens.space.s

            Rectangle {
                visible: root.icon !== ""
                implicitWidth: 30
                implicitHeight: 30
                radius: Tokens.radius.s
                color: Theme.secondaryContainer
                Icon {
                    anchors.centerIn: parent
                    text: root.icon
                    size: 18
                    fill: 1
                    color: Theme.secondaryContainerFg
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: -2
                StyledText {
                    Layout.fillWidth: true
                    text: root.title
                    font.pixelSize: Tokens.font.l
                    font.weight: Font.Bold
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.subtitle
                    font.pixelSize: Tokens.font.xs
                    color: Theme.surfaceVariantFg
                }
            }
            RowLayout {
                id: trail
                spacing: Tokens.space.xs
            }
        }

        Item {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
