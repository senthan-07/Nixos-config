pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.config
import qs.components
import qs.services

// Wallpaper thumbnails with the current one marked.
GridView {
    id: root

    property var items: []
    property int selected: 0
    readonly property int columns: Math.max(1, Math.min(5, Math.floor(width / 210)))
    readonly property real naturalHeight: Math.ceil(items.length / columns) * cellHeight

    signal hovered(int index)
    signal activated(int index, var mouse)

    model: items
    currentIndex: selected
    // A model reset moves currentIndex internally; re-apply the selection.
    onModelChanged: Qt.callLater(() => currentIndex = Qt.binding(() => selected))
    onSelectedChanged: if (currentIndex !== selected) currentIndex = Qt.binding(() => selected)
    cellWidth: Math.floor(width / columns)
    cellHeight: Math.round((cellWidth - 16) * 10 / 16) + 44
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    highlightFollowsCurrentItem: true
    highlightMoveDuration: 140
    preferredHighlightBegin: 0
    preferredHighlightEnd: height
    highlightRangeMode: GridView.ApplyRange
    cacheBuffer: 600

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
        readonly property bool isCurrent: modelData.path === Wallpapers.current
        width: root.cellWidth
        height: root.cellHeight

        Item {
            id: frame
            x: 8
            y: 8
            width: parent.width - 16
            height: parent.height - 44
            scale: mouse.pressed ? 0.97 : mouse.containsMouse ? 1.03 : 1
            Behavior on scale { Anim { duration: Motion.duration.short } }

            Rectangle {
                anchors.fill: parent
                radius: Tokens.radius.m
                color: Theme.surfaceHighest
                Icon {
                    anchors.centerIn: parent
                    text: "image"
                    size: 28
                    color: Theme.surfaceVariantFg
                    visible: img.status !== Image.Ready
                }
            }

            Image {
                id: img
                anchors.fill: parent
                source: `file://${cell.modelData.path}`
                sourceSize.width: 360
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }

            Rectangle {
                id: mask
                anchors.fill: parent
                radius: Tokens.radius.m
                visible: false
                layer.enabled: true
            }

            MultiEffect {
                anchors.fill: parent
                source: img
                maskEnabled: true
                maskSource: mask
                visible: img.status === Image.Ready
                opacity: visible ? 1 : 0
                Behavior on opacity { Anim { duration: Motion.duration.short } }
            }

            Rectangle {
                anchors.fill: parent
                radius: Tokens.radius.m
                color: "transparent"
                border.width: cell.isSelected ? 3 : 0
                border.color: Theme.primary
            }

            Rectangle {
                visible: cell.isCurrent
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                width: 28
                height: 28
                radius: 14
                color: Theme.primary
                Icon {
                    anchors.centerIn: parent
                    text: "check"
                    size: 18
                    fill: 1
                    color: Theme.primaryFg
                }
            }
        }

        StyledText {
            anchors.top: frame.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 24
            horizontalAlignment: Text.AlignHCenter
            text: cell.modelData.title || ""
            font.pixelSize: Tokens.font.m
            font.weight: cell.isSelected ? Font.DemiBold : Font.Normal
            color: cell.isSelected ? Spot.selectedFg : Theme.surfaceVariantFg
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
