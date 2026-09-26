pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// Sectioned result list: headers, rows, desktop-action sub rows and answer cards.
ListView {
    id: root

    property var items: []
    property int selected: -1
    property string confirmKey: ""
    property string copiedKey: ""

    signal hovered(int index)
    signal activated(int index, var mouse)
    signal secondary(int index)

    readonly property real naturalHeight: contentHeight

    model: items
    currentIndex: selected
    // A model reset moves currentIndex internally; re-apply the selection.
    onModelChanged: Qt.callLater(() => currentIndex = Qt.binding(() => selected))
    onSelectedChanged: if (currentIndex !== selected) currentIndex = Qt.binding(() => selected)
    clip: true
    spacing: 2
    boundsBehavior: Flickable.StopAtBounds
    reuseItems: false
    cacheBuffer: 400

    highlightFollowsCurrentItem: true
    highlightMoveDuration: 160
    highlightMoveVelocity: -1
    highlightResizeDuration: 160
    highlightResizeVelocity: -1
    preferredHighlightBegin: 40
    preferredHighlightEnd: height - 40
    highlightRangeMode: ListView.ApplyRange

    highlight: Rectangle {
        radius: Tokens.radius.l
        color: {
            const it = root.items[root.selected];
            return it && it.kind === "answer" ? "transparent" : Spot.selected;
        }
    }

    // Only a real pointer move selects; content scrolling under a still pointer does not.
    property point lastPointer: Qt.point(-1, -1)
    function pointerMoved(index, p) {
        if (p.x === lastPointer.x && p.y === lastPointer.y) return;
        lastPointer = p;
        hovered(index);
    }

    add: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.duration.short }
    }
    displaced: Transition {
        NumberAnimation { properties: "y"; duration: Motion.duration.short; easing.type: Easing.OutCubic }
    }

    delegate: Item {
        id: cell
        required property var modelData
        required property int index
        readonly property var it: modelData
        readonly property bool isHeader: it.kind === "header"
        readonly property bool isAnswer: it.kind === "answer"
        readonly property bool isSelected: index === root.selected

        width: root.width
        height: isHeader ? Spot.headerHeight : isAnswer ? Spot.answerHeight : row.implicitHeight

        // Section header
        Row {
            visible: cell.isHeader
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            spacing: 8
            StyledText {
                text: cell.it.title || ""
                font.pixelSize: Tokens.font.s
                font.weight: Font.DemiBold
                font.letterSpacing: 0.4
                color: Theme.primary
            }
            StyledText {
                visible: !!cell.it.note
                text: cell.it.note || ""
                font.pixelSize: Tokens.font.s
                color: Theme.alpha(Theme.surfaceVariantFg, 0.8)
            }
        }

        // Hover layer
        Rectangle {
            anchors.fill: parent
            visible: !cell.isHeader && !cell.isAnswer
            radius: Tokens.radius.l
            color: mouse.containsMouse && !cell.isSelected ? Spot.hover : "transparent"
            Behavior on color { ColorAnim {} }
        }

        ResultRow {
            id: row
            visible: !cell.isHeader && !cell.isAnswer
            anchors.left: parent.left
            anchors.right: parent.right
            item: cell.isHeader || cell.isAnswer ? ({}) : cell.it
            selected: cell.isSelected
            confirming: root.confirmKey !== "" && root.confirmKey === cell.it.key
        }

        AnswerCard {
            visible: cell.isAnswer
            anchors.fill: parent
            answer: cell.isAnswer ? cell.it.answer : ({})
            selected: cell.isSelected
            copied: root.copiedKey === cell.it.key
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            enabled: !cell.isHeader
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPositionChanged: m => root.pointerMoved(cell.index, mapToGlobal(m.x, m.y))
            onClicked: m => {
                if (m.button === Qt.RightButton) root.secondary(cell.index);
                else root.activated(cell.index, m);
            }
        }
    }
}
