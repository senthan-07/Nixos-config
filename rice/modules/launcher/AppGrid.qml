pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// Launchpad-style application grid.
GridView {
    id: root

    property var items: []
    property int selected: 0
    readonly property int columns: Math.max(1, Math.floor(width / Spot.gridCell))
    readonly property real naturalHeight: Math.ceil(items.length / columns) * cellHeight

    signal hovered(int index)
    signal activated(int index, var mouse)
    signal secondary(int index)

    model: items
    currentIndex: selected
    // A model reset moves currentIndex internally; re-apply the selection.
    onModelChanged: Qt.callLater(() => currentIndex = Qt.binding(() => selected))
    onSelectedChanged: if (currentIndex !== selected) currentIndex = Qt.binding(() => selected)
    cellWidth: Math.floor(width / columns)
    cellHeight: Spot.gridCellHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    highlightFollowsCurrentItem: true
    highlightMoveDuration: 140
    preferredHighlightBegin: 0
    preferredHighlightEnd: height
    highlightRangeMode: GridView.ApplyRange

    highlight: Item {
        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: Tokens.radius.l
            color: Spot.selected
        }
    }

    property point lastPointer: Qt.point(-1, -1)

    delegate: Item {
        id: cell
        required property var modelData
        required property int index
        readonly property bool isSelected: index === root.selected
        width: root.cellWidth
        height: root.cellHeight

        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: Tokens.radius.l
            color: mouse.containsMouse && !cell.isSelected ? Spot.hover : "transparent"
            Behavior on color { ColorAnim {} }
        }

        ItemIcon {
            id: icon
            anchors.horizontalCenter: parent.horizontalCenter
            y: 16
            size: 52
            item: cell.modelData
            scale: mouse.pressed ? 0.92 : (mouse.containsMouse || cell.isSelected) ? 1.08 : 1
            Behavior on scale { Anim { duration: Motion.duration.short; easing.bezierCurve: Motion.curve.springFast } }
        }

        StyledText {
            anchors.top: icon.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 16
            horizontalAlignment: Text.AlignHCenter
            text: cell.modelData.title || ""
            wrapMode: Text.Wrap
            maximumLineCount: 2
            lineHeight: 1.05
            font.pixelSize: Tokens.font.m
            font.weight: cell.isSelected ? Font.DemiBold : Font.Normal
            color: cell.isSelected ? Spot.selectedFg : Theme.surfaceFg
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            anchors.margins: 4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPositionChanged: m => {
                const p = mapToGlobal(m.x, m.y);
                if (p.x === root.lastPointer.x && p.y === root.lastPointer.y) return;
                root.lastPointer = p;
                root.hovered(cell.index);
            }
            onClicked: m => m.button === Qt.RightButton ? root.secondary(cell.index) : root.activated(cell.index, m)
        }
    }
}
