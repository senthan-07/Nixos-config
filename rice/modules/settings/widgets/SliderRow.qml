import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Settings row with a value readout and a full-width slider underneath.
//   SliderRow {
//       icon: "opacity"; label: "Panel opacity"
//       from: 0.5; to: 1; stepSize: 0.05
//       value: Settings.data.surfaceOpacity
//       format: v => Math.round(v * 100) + "%"
//       onMoved: v => Settings.data.surfaceOpacity = v   // debounced while dragging
//   }
Surface {
    id: root

    property string icon
    property string label
    property string description
    property real from: 0
    property real to: 1
    property real stepSize: 0
    property real value: 0
    property var format: v => String(Math.round(v * 100) / 100)
    property string fromLabel
    property string toLabel

    signal moved(real value)

    // Local value while the user is dragging, so the readout follows the thumb
    // without writing settings on every pixel.
    property real pending: value
    property bool dragging: false
    readonly property real shown: dragging ? pending : value

    function snap(v) {
        let out = from + v * (to - from);
        if (stepSize > 0) out = from + Math.round((out - from) / stepSize) * stepSize;
        return Math.max(Math.min(from, to), Math.min(Math.max(from, to), out));
    }

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + Tokens.space.m * 2
    radius: Tokens.radius.m
    base: Theme.surfaceContainer
    activeFocusOnTab: true

    Keys.onLeftPressed: nudge(-1)
    Keys.onRightPressed: nudge(1)
    function nudge(d) {
        const step = stepSize > 0 ? stepSize : (to - from) / 20;
        const next = Math.max(Math.min(from, to), Math.min(Math.max(from, to), value + d * step));
        moved(next);
    }

    Timer {
        id: commit
        interval: 120
        onTriggered: { root.moved(root.pending); root.dragging = false; }
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tokens.space.l
        anchors.rightMargin: Tokens.space.l
        spacing: Tokens.space.s

        RowLayout {
            Layout.fillWidth: true
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
            Rectangle {
                implicitHeight: 28
                implicitWidth: Math.max(48, readout.implicitWidth + Tokens.space.m * 2)
                radius: height / 2
                color: root.dragging || root.activeFocus ? Theme.primary : Theme.secondaryContainer
                Behavior on color { ColorAnim {} }
                StyledText {
                    id: readout
                    anchors.centerIn: parent
                    text: root.format(root.shown)
                    color: root.dragging || root.activeFocus ? Theme.primaryFg : Theme.secondaryContainerFg
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }
        }

        Slider {
            Layout.fillWidth: true
            Layout.leftMargin: root.icon !== "" ? 22 + Tokens.space.l : 0
            implicitHeight: 24
            value: (root.shown - root.from) / (root.to - root.from)
            onMoved: v => {
                root.pending = root.snap(v);
                root.dragging = true;
                commit.restart();
            }
        }

        RowLayout {
            visible: root.fromLabel !== "" || root.toLabel !== ""
            Layout.fillWidth: true
            Layout.leftMargin: root.icon !== "" ? 22 + Tokens.space.l : 0
            StyledText {
                text: root.fromLabel
                font.pixelSize: Tokens.font.xs
                color: Theme.surfaceVariantFg
            }
            Item { Layout.fillWidth: true }
            StyledText {
                text: root.toLabel
                font.pixelSize: Tokens.font.xs
                color: Theme.surfaceVariantFg
            }
        }
    }
}
