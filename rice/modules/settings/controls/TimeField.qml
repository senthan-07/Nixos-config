import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// "HH:mm" picker: two spin segments. Wheel / arrow keys / the chevrons change a
// segment (minutes in 5-minute steps). Emits edited("HH:mm").
Rectangle {
    id: root

    property string value: "00:00"
    property string label
    signal edited(string value)

    readonly property int hours: parseInt(value.split(":")[0]) || 0
    readonly property int minutes: parseInt(value.split(":")[1]) || 0

    function pad(n) { return String(n).padStart(2, "0"); }
    function set(h, m) {
        h = (h + 24) % 24;
        m = (m + 60) % 60;
        edited(`${pad(h)}:${pad(m)}`);
    }

    implicitWidth: row.implicitWidth + Tokens.space.m * 2
    implicitHeight: 56
    radius: Tokens.radius.m
    color: Theme.surfaceHigh

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.space.xs

        StyledText {
            visible: root.label !== ""
            text: root.label
            color: Theme.surfaceVariantFg
            Layout.rightMargin: Tokens.space.s
        }

        Repeater {
            model: [
                { unit: "h", step: 1 },
                { unit: "m", step: 5 }
            ]
            RowLayout {
                id: seg
                required property var modelData
                required property int index
                spacing: 0

                StyledText {
                    visible: seg.index === 1
                    text: ":"
                    font.pixelSize: Tokens.font.xxl
                    color: Theme.surfaceVariantFg
                }
                Rectangle {
                    implicitWidth: 56
                    implicitHeight: 44
                    radius: Tokens.radius.s
                    color: box.activeFocus ? Theme.primaryContainer : area.containsMouse ? Theme.surfaceHighest : "transparent"
                    Behavior on color { ColorAnim {} }

                    Item {
                        id: box
                        anchors.fill: parent
                        activeFocusOnTab: true
                        Accessible.role: Accessible.SpinBox
                        Accessible.name: `${root.label} ${seg.modelData.unit === "h" ? "hours" : "minutes"}`
                        function bump(d) {
                            if (seg.modelData.unit === "h") root.set(root.hours + d, root.minutes);
                            else root.set(root.hours, Math.round((root.minutes + d * seg.modelData.step) / seg.modelData.step) * seg.modelData.step);
                        }
                        Keys.onUpPressed: bump(1)
                        Keys.onDownPressed: bump(-1)
                    }
                    StyledText {
                        anchors.centerIn: parent
                        text: root.pad(seg.modelData.unit === "h" ? root.hours : root.minutes)
                        font.pixelSize: Tokens.font.xxl
                        font.features: { "tnum": 1 }
                        color: box.activeFocus ? Theme.primaryContainerFg : Theme.surfaceFg
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.SizeVerCursor
                        onClicked: m => { box.forceActiveFocus(); box.bump(m.y < height / 2 ? 1 : -1); }
                        onWheel: w => box.bump(w.angleDelta.y > 0 ? 1 : -1)
                    }
                    Icon {
                        visible: area.containsMouse
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: -6
                        text: "arrow_drop_up"
                        size: 18
                        color: Theme.surfaceVariantFg
                    }
                    Icon {
                        visible: area.containsMouse
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: -6
                        text: "arrow_drop_down"
                        size: 18
                        color: Theme.surfaceVariantFg
                    }
                }
            }
        }
    }
}
