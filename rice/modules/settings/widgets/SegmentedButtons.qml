import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Segmented control (single select): one rounded track, equal-width options
// and a highlight that slides to the selected one.
//   SegmentedButtons {
//       model: [{ value: "top", label: "Top", icon: "vertical_align_top" }, …]
//       value: Settings.data.barPosition
//       onActivated: v => Settings.data.barPosition = v
//   }
// Left/Right arrows move the selection when focused.
Item {
    id: root

    property var model: []
    property var value
    property bool iconOnly: false
    property int segmentHeight: 40
    property int gap: 2                 // kept for API compatibility
    readonly property int pad: 4

    signal activated(var value)

    readonly property int currentIndex: model.findIndex(m => m.value === value)
    readonly property int count: model.length

    // Widest option decides every option's width, so they're all equal.
    property real contentWidth: 0
    function measure() {
        let w = 0;
        for (let i = 0; i < measurer.count; i++) {
            const it = measurer.itemAt(i);
            if (it) w = Math.max(w, it.implicitWidth);
        }
        contentWidth = w;
    }
    readonly property real segWidth: iconOnly ? segmentHeight + Tokens.space.m
        : contentWidth + Tokens.space.xl * 2
    readonly property real innerWidth: width - pad * 2
    readonly property real slot: count > 0 ? innerWidth / count : 0

    implicitHeight: segmentHeight
    implicitWidth: segWidth * count + pad * 2
    activeFocusOnTab: true

    Keys.onLeftPressed: step(-1)
    Keys.onRightPressed: step(1)
    function step(d) {
        const i = Math.max(0, Math.min(count - 1, currentIndex + d));
        if (i !== currentIndex) activated(model[i].value);
    }

    // Hidden copies of each option's content, only used for measuring.
    Repeater {
        id: measurer
        model: root.model
        delegate: Row {
            required property var modelData
            visible: false
            spacing: Tokens.space.xs
            Icon { visible: !!parent.modelData.icon; text: parent.modelData.icon || ""; size: 18 }
            StyledText { visible: !root.iconOnly; text: parent.modelData.label || ""; font.weight: Font.DemiBold }
            onImplicitWidthChanged: root.measure()
            Component.onCompleted: root.measure()
        }
    }

    // Track
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.surfaceHighest
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.primary
    }

    // Sliding selection
    Rectangle {
        visible: root.currentIndex >= 0
        x: root.pad + root.currentIndex * root.slot
        y: root.pad
        width: root.slot
        height: root.height - root.pad * 2
        radius: height / 2
        color: Theme.primary
        Behavior on x { Anim { duration: Motion.duration.medium; easing.bezierCurve: Motion.curve.emphasizedDecel } }
    }

    Row {
        x: root.pad
        y: root.pad
        height: root.height - root.pad * 2

        Repeater {
            model: root.model

            Item {
                id: seg
                required property var modelData
                required property int index
                readonly property bool selected: root.currentIndex === index
                readonly property color fg: selected ? Theme.primaryFg : Theme.surfaceVariantFg

                width: root.slot
                height: parent.height

                // Hover state layer on unselected options.
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Theme.alpha(Theme.surfaceFg, !seg.selected && area.containsMouse ? 0.08 : 0)
                    Behavior on color { ColorAnim {} }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: Tokens.space.xs
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !!seg.modelData.icon
                        text: seg.modelData.icon || ""
                        size: 18
                        fill: seg.selected ? 1 : 0
                        color: seg.fg
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root.iconOnly && !!seg.modelData.label
                        text: seg.modelData.label || ""
                        color: seg.fg
                        font.weight: seg.selected ? Font.DemiBold : Font.Medium
                    }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.forceActiveFocus();
                        if (!seg.selected) root.activated(seg.modelData.value);
                    }
                }
            }
        }
    }
}
