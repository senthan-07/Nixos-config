import QtQuick
import QtQuick.Effects
import qs.config
import qs.components

// Popup surface used by the dock: a rounded M3 container with a small tail
// pointing at the icon it belongs to, a soft shadow and a scale/fade entrance.
//   DockBubble { open: …; tailX: …; contentItem children … }
Item {
    id: root

    property bool open: false
    // Horizontal position of the tail tip, in this item's coordinates.
    property real tailX: width / 2
    property real tailSize: 8
    // Transparent space under the tail that keeps the pointer "inside" while it
    // travels from the dock icon up to the bubble.
    property real bridge: 0
    property color color: Theme.surfaceContainer
    property real radius: Tokens.radius.l
    property real padding: Tokens.space.s
    property real contentWidth: 200
    property real contentHeight: 100
    default property alias content: body.data
    readonly property alias body: body
    readonly property bool hovered: hover.hovered || bridgeHover.hovered
    // 0..1 visual progress, useful for staggered children.
    property real progress: open ? 1 : 0

    visible: open || progress > 0.001
    implicitWidth: contentWidth + padding * 2
    implicitHeight: contentHeight + padding * 2 + tailSize + bridge
    Behavior on progress { Anim { duration: root.open ? Motion.duration.medium : Motion.duration.short; easing.bezierCurve: root.open ? Motion.curve.emphasizedDecel : Motion.curve.emphasizedAccel } }

    // Only a narrow bridge above the tail keeps the popup alive, so the rest
    // of the gap still reaches the (magnified) dock icons underneath.
    Item {
        id: bridgeArea
        x: Math.max(0, Math.min(root.width, root.tailX) - 36)
        width: 72
        y: root.height - root.bridge - root.tailSize
        height: root.bridge + root.tailSize
        HoverHandler { id: bridgeHover }
    }

    Item {
        id: frame
        width: parent.width
        height: parent.height - root.bridge
        opacity: Math.min(1, root.progress * 1.6)
        scale: 0.92 + 0.08 * root.progress
        transformOrigin: Item.Bottom
        transform: Translate { y: (1 - root.progress) * 10 }

        HoverHandler { id: hover }

        RectangularShadow {
            anchors.fill: bg
            radius: bg.radius
            blur: 24
            spread: -2
            offset.y: 6
            color: Theme.alpha(Theme.shadow, Theme.dark ? 0.5 : 0.22)
        }

        // Tail: a rotated square peeking out under the body.
        Rectangle {
            id: tail
            width: root.tailSize * 2
            height: width
            rotation: 45
            x: Math.max(root.radius, Math.min(parent.width - root.radius, root.tailX)) - width / 2
            y: bg.height - height / 2 - 1
            color: root.color
            border.width: 1
            border.color: Theme.alpha(Theme.outlineVariant, 0.7)
            visible: root.tailSize > 0
        }

        Rectangle {
            id: bg
            width: parent.width
            height: parent.height - root.tailSize
            radius: root.radius
            color: root.color
            border.width: 1
            border.color: Theme.alpha(Theme.outlineVariant, 0.7)
        }

        // Hide the seam where the tail meets the body border.
        Rectangle {
            visible: tail.visible
            x: tail.x + 2
            width: tail.width - 4
            y: bg.height - 3
            height: 3
            color: root.color
        }

        Item {
            id: body
            x: root.padding
            y: root.padding
            width: bg.width - root.padding * 2
            height: bg.height - root.padding * 2
        }
    }
}
