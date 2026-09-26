import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// M3 expressive connected button group (single select).
//   SegmentedButtons {
//       model: [{ value: "top", label: "Top", icon: "vertical_align_top" }, …]
//       value: Settings.data.barPosition
//       onActivated: v => Settings.data.barPosition = v
//   }
// The selected segment morphs into a full pill; the others keep squarer inner corners.
// Left/Right arrows move the selection when focused.
Item {
    id: root

    property var model: []
    property var value
    property bool iconOnly: false
    property int segmentHeight: 40
    property int gap: 2

    signal activated(var value)

    readonly property int currentIndex: model.findIndex(m => m.value === value)

    implicitHeight: segmentHeight
    implicitWidth: row.implicitWidth
    activeFocusOnTab: true

    Keys.onLeftPressed: step(-1)
    Keys.onRightPressed: step(1)
    function step(d) {
        const i = Math.max(0, Math.min(model.length - 1, currentIndex + d));
        if (i !== currentIndex) activated(model[i].value);
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: root.gap

        Repeater {
            model: root.model

            Surface {
                id: seg
                required property var modelData
                required property int index
                readonly property bool selected: root.currentIndex === index
                readonly property bool first: index === 0
                readonly property bool last: index === root.model.length - 1
                readonly property real outer: height / 2
                readonly property real inner: selected ? height / 2 : Tokens.radius.xs

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: segRow.implicitWidth + Tokens.space.xl * 2
                Layout.minimumWidth: root.iconOnly ? root.segmentHeight + Tokens.space.m : 0

                radius: 0
                topLeftRadius: first ? outer : inner
                bottomLeftRadius: first ? outer : inner
                topRightRadius: last ? outer : inner
                bottomRightRadius: last ? outer : inner
                interactive: true
                base: selected ? Theme.primary : Theme.surfaceHighest
                content: selected ? Theme.primaryFg : Theme.surfaceVariantFg
                border.width: root.activeFocus && selected ? 2 : 0
                border.color: Theme.primaryContainer
                onClicked: { root.forceActiveFocus(); if (!selected) root.activated(modelData.value); }

                Behavior on topLeftRadius { Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.springDefault } }
                Behavior on bottomLeftRadius { Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.springDefault } }
                Behavior on topRightRadius { Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.springDefault } }
                Behavior on bottomRightRadius { Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.springDefault } }

                RowLayout {
                    id: segRow
                    anchors.centerIn: parent
                    spacing: Tokens.space.xs

                    Item {
                        // Check mark slides in when selected (only for labelled segments without an icon).
                        visible: !seg.modelData.icon && !root.iconOnly
                        implicitWidth: seg.selected ? 18 : 0
                        implicitHeight: 18
                        clip: true
                        Behavior on implicitWidth { Anim { duration: Motion.duration.short } }
                        Icon {
                            anchors.centerIn: parent
                            text: "check"
                            size: 18
                            color: seg.content
                            scale: seg.selected ? 1 : 0.4
                            Behavior on scale { Anim { duration: Motion.duration.short } }
                        }
                    }
                    Icon {
                        visible: !!seg.modelData.icon
                        text: seg.modelData.icon || ""
                        size: 20
                        fill: seg.selected ? 1 : 0
                        color: seg.content
                    }
                    StyledText {
                        visible: !root.iconOnly && !!seg.modelData.label
                        text: seg.modelData.label || ""
                        color: seg.content
                        font.weight: seg.selected ? Font.DemiBold : Font.Medium
                    }
                }
            }
        }
    }
}
