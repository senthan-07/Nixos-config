import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

Surface {
    id: root

    property int offset: 0   // months relative to today
    readonly property date today: Time.now
    readonly property date month: new Date(today.getFullYear(), today.getMonth() + offset, 1)
    // Monday-first grid of 42 days.
    readonly property var days: {
        const first = (month.getDay() + 6) % 7;
        const out = [];
        for (let i = 0; i < 42; i++)
            out.push(new Date(month.getFullYear(), month.getMonth(), i - first + 1));
        return out;
    }

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + Tokens.space.l * 2
    radius: Tokens.radius.xl
    base: Theme.surfaceContainer

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: Tokens.space.l
        spacing: Tokens.space.s

        RowLayout {
            StyledText {
                Layout.fillWidth: true
                text: Qt.formatDate(root.month, "MMMM yyyy")
                font.pixelSize: Tokens.font.l
                font.weight: Font.DemiBold
            }
            IconButton { size: 30; icon: "chevron_left"; onClicked: root.offset-- }
            IconButton { size: 30; icon: "today"; visible: root.offset !== 0; onClicked: root.offset = 0 }
            IconButton { size: 30; icon: "chevron_right"; onClicked: root.offset++ }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 7
            rowSpacing: 2
            columnSpacing: 2

            Repeater {
                model: ["M", "T", "W", "T", "F", "S", "S"]
                StyledText {
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.pixelSize: Tokens.font.xs
                    font.weight: Font.Bold
                    color: Theme.surfaceVariantFg
                }
            }

            Repeater {
                model: root.days

                Rectangle {
                    id: day
                    required property var modelData
                    readonly property bool inMonth: modelData.getMonth() === root.month.getMonth()
                    readonly property bool isToday: modelData.toDateString() === root.today.toDateString()

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 32
                    radius: height / 2
                    color: isToday ? Theme.primary : "transparent"

                    StyledText {
                        anchors.centerIn: parent
                        text: day.modelData.getDate()
                        font.features: { "tnum": 1 }
                        font.weight: day.isToday ? Font.Bold : Font.Normal
                        color: day.isToday ? Theme.primaryFg : day.inMonth ? Theme.surfaceFg : Theme.outline
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
