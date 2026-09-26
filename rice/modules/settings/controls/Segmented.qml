import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// M3 segmented button. options: [{ value, label, icon? }]
Rectangle {
    id: root

    property var options: []
    property var value
    signal selected(var value)

    implicitHeight: 40
    implicitWidth: row.implicitWidth
    radius: height / 2
    color: "transparent"
    border.width: 1
    border.color: Theme.outline
    clip: true

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 0

        Repeater {
            model: root.options

            Surface {
                id: seg
                required property var modelData
                required property int index
                readonly property bool active: root.value === modelData.value

                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitWidth: segRow.implicitWidth + Tokens.space.l * 2
                radius: 0
                interactive: true
                base: active ? Theme.secondaryContainer : Theme.alpha(Theme.surface, 0)
                content: active ? Theme.secondaryContainerFg : Theme.surfaceFg
                onClicked: root.selected(modelData.value)

                Rectangle {
                    visible: seg.index > 0
                    width: 1
                    height: parent.height
                    color: Theme.outline
                }

                RowLayout {
                    id: segRow
                    anchors.centerIn: parent
                    spacing: Tokens.space.xs
                    Icon {
                        visible: seg.active || (seg.modelData.icon ?? "") !== ""
                        text: seg.active ? "check" : (seg.modelData.icon ?? "")
                        size: 18
                        color: seg.content
                    }
                    StyledText {
                        text: seg.modelData.label
                        font.weight: Font.Medium
                        color: seg.content
                    }
                }
            }
        }
    }
}
