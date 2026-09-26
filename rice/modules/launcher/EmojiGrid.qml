pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// Emoji picker grid.
GridView {
    id: root

    property var items: []
    property int selected: 0
    readonly property int columns: Math.max(1, Math.floor(width / Spot.emojiCell))
    readonly property real naturalHeight: Math.ceil(items.length / columns) * cellHeight

    signal hovered(int index)
    signal activated(int index, var mouse)

    model: items
    currentIndex: selected
    // A model reset moves currentIndex internally; re-apply the selection.
    onModelChanged: Qt.callLater(() => currentIndex = Qt.binding(() => selected))
    onSelectedChanged: if (currentIndex !== selected) currentIndex = Qt.binding(() => selected)
    cellWidth: Math.floor(width / columns)
    cellHeight: Spot.emojiCell
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    highlightFollowsCurrentItem: true
    highlightMoveDuration: 110
    preferredHighlightBegin: 0
    preferredHighlightEnd: height
    highlightRangeMode: GridView.ApplyRange
    cacheBuffer: 400

    highlight: Item {
        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: Tokens.radius.m
            color: Spot.selected
        }
    }

    property point lastPointer: Qt.point(-1, -1)

    delegate: Item {
        id: cell
        required property var modelData
        required property int index
        width: root.cellWidth
        height: root.cellHeight

        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: Tokens.radius.m
            color: mouse.containsMouse && cell.index !== root.selected ? Spot.hover : "transparent"
        }

        Text {
            anchors.centerIn: parent
            text: cell.modelData.glyph
            font.pixelSize: 30
            renderType: Text.NativeRendering
            scale: mouse.pressed ? 0.85 : cell.index === root.selected ? 1.12 : 1
            Behavior on scale { Anim { duration: Motion.duration.short; easing.bezierCurve: Motion.curve.springFast } }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPositionChanged: m => {
                const p = mapToGlobal(m.x, m.y);
                if (p.x === root.lastPointer.x && p.y === root.lastPointer.y) return;
                root.lastPointer = p;
                root.hovered(cell.index);
            }
            onClicked: m => root.activated(cell.index, m)
        }
    }
}
