import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Compact month view. Scroll or use the chevrons to change month.
Surface {
    id: root

    property int offset: 0
    readonly property date today: Time.now
    readonly property date month: new Date(today.getFullYear(), today.getMonth() + offset, 1)
    readonly property var days: {
        const first = (month.getDay() + 6) % 7;     // Monday first
        const out = [];
        for (let i = 0; i < 42; i++)
            out.push(new Date(month.getFullYear(), month.getMonth(), i - first + 1));
        return out;
    }

    radius: Tokens.radius.xl
    base: Theme.surfaceHigh

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.space.m
        spacing: Tokens.space.xs

        RowLayout {
            Layout.fillWidth: true
            spacing: 0
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    text: Qt.formatDate(root.month, "MMMM")
                    font.pixelSize: Tokens.font.l
                    font.weight: Font.Bold
                }
                StyledText {
                    text: Qt.formatDate(root.month, "yyyy")
                    font.pixelSize: Tokens.font.xs
                    color: Theme.surfaceVariantFg
                }
            }
            IconButton { size: 28; iconSize: 18; icon: "today"; visible: root.offset !== 0; onClicked: root.offset = 0 }
            IconButton { size: 28; iconSize: 18; icon: "chevron_left"; onClicked: root.offset-- }
            IconButton { size: 28; iconSize: 18; icon: "chevron_right"; onClicked: root.offset++ }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 7
            rowSpacing: 0
            columnSpacing: 0

            Repeater {
                model: ["M", "T", "W", "T", "F", "S", "S"]
                StyledText {
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.pixelSize: Tokens.font.xs
                    font.weight: Font.Bold
                    color: index >= 5 ? Theme.tertiary : Theme.surfaceVariantFg
                }
            }

            Repeater {
                model: root.days
                Item {
                    id: cell
                    required property var modelData
                    readonly property bool inMonth: modelData.getMonth() === root.month.getMonth()
                    readonly property bool isToday: modelData.toDateString() === root.today.toDateString()
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    implicitHeight: 24

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height, 26)
                        height: width
                        radius: width / 2
                        color: Theme.primary
                        visible: cell.isToday
                    }
                    StyledText {
                        anchors.centerIn: parent
                        text: cell.modelData.getDate()
                        font.pixelSize: Tokens.font.s
                        font.features: { "tnum": 1 }
                        font.weight: cell.isToday ? Font.Bold : Font.Normal
                        color: cell.isToday ? Theme.primaryFg : Theme.surfaceFg
                        opacity: cell.inMonth ? 1 : 0.35
                    }
                }
            }
        }
    }
}
