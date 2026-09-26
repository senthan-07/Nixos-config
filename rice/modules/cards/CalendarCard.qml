import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Month grid with an expressive "today" header. Scroll or use the chevrons
// to page months; clicking the header jumps back to today.
CardFrame {
    id: root

    property int offset: 0
    readonly property date today: Time.now
    readonly property date month: new Date(today.getFullYear(), today.getMonth() + offset, 1)
    readonly property var days: {
        const first = (month.getDay() + 6) % 7;
        const out = [];
        for (let i = 0; i < 42; i++)
            out.push(new Date(month.getFullYear(), month.getMonth(), i - first + 1));
        return out;
    }
    readonly property int rows: {
        const first = (month.getDay() + 6) % 7;
        const len = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
        return Math.ceil((first + len) / 7);
    }

    implicitWidth: 272
    implicitHeight: 272

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.space.xs

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.space.s

            Rectangle {
                implicitWidth: 44
                implicitHeight: 44
                radius: Tokens.radius.m
                color: Theme.primary
                StyledText {
                    anchors.centerIn: parent
                    text: root.today.getDate()
                    color: Theme.primaryFg
                    font.family: CardStyle.display
                    font.pixelSize: 22
                    font.weight: Font.Black
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: -2
                StyledText {
                    Layout.fillWidth: true
                    text: Qt.formatDate(root.month, "MMMM")
                    font.pixelSize: Tokens.font.l
                    font.weight: Font.Bold
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.offset === 0 ? Qt.formatDate(root.today, "dddd, yyyy") : Qt.formatDate(root.month, "yyyy")
                    color: Theme.surfaceVariantFg
                    font.pixelSize: Tokens.font.s
                }
            }
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
                model: root.days.slice(0, root.rows * 7)

                Item {
                    id: day
                    required property var modelData
                    readonly property bool inMonth: modelData.getMonth() === root.month.getMonth()
                    readonly property bool isToday: modelData.toDateString() === root.today.toDateString()
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 1

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) - 2
                        height: width
                        radius: width / 2
                        visible: day.isToday
                        color: Theme.primary
                    }
                    StyledText {
                        anchors.centerIn: parent
                        text: day.modelData.getDate()
                        font.pixelSize: Tokens.font.s
                        font.features: { "tnum": 1 }
                        font.weight: day.isToday ? Font.Bold : Font.Normal
                        color: day.isToday ? Theme.primaryFg : day.inMonth ? Theme.surfaceFg : Theme.alpha(Theme.outline, 0.7)
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: w => root.offset += w.angleDelta.y > 0 ? -1 : 1
    }
}
