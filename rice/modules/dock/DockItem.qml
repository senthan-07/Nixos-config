import QtQuick
import QtQuick.Effects
import qs.config
import qs.components
import qs.services

// One application slot: magnifiable icon, launch bounce, running indicators
// and all pointer handling (click, middle-click, right-click, drag).
Item {
    id: root

    required property string key
    // Current (magnified) icon edge and the resting one.
    property real size: 48
    property real restSize: 48
    property real maxSize: 96
    property bool dragging: false
    property bool highlighted: false

    readonly property var windows: Dock.windowsFor(key)
    readonly property bool running: windows.length > 0
    readonly property bool focused: windows.some(t => t.activated)
    readonly property bool launching: Dock.launching[key] !== undefined
    readonly property string name: Dock.nameFor(key)
    readonly property bool pressed: mouse.pressed && !moved
    readonly property alias containsMouse: mouse.containsMouse
    readonly property Item iconItem: icon

    property bool moved: false
    property point pressPos

    signal entered()
    signal exited()
    signal activated()
    signal contextRequested()
    signal middleClicked()
    signal dragStarted(point pos)
    signal dragMoved(point pos)
    signal dragFinished(point pos)

    width: size
    height: size

    // Entrance when the slot appears (app launched / pinned).
    property real presence: 0
    Component.onCompleted: presence = 1
    Behavior on presence { Anim { duration: Motion.duration.long; easing.bezierCurve: Motion.curve.springDefault } }

    // Launch acknowledgement: two soft hops, repeated while waiting for a window.
    property real hop: 0
    SequentialAnimation {
        id: bounce
        loops: 2
        running: root.launching
        Anim { target: root; property: "hop"; to: root.restSize * 0.38; duration: 260; easing.bezierCurve: Motion.curve.standardDecel }
        Anim { target: root; property: "hop"; to: 0; duration: 420; easing.type: Easing.OutBounce }
        onStopped: root.hop = 0
    }

    Item {
        id: icon
        width: root.maxSize
        height: root.maxSize
        x: (root.width - width) / 2
        y: root.height - height - root.hop
        transformOrigin: Item.Bottom
        scale: root.size / root.maxSize * (0.4 + 0.6 * root.presence)
        opacity: root.dragging ? 0 : root.presence

        property real shade: root.pressed || root.highlighted ? 0.28 : 0
        Behavior on shade { Anim { duration: Motion.duration.tiny } }
        layer.enabled: shade > 0
        layer.effect: MultiEffect { brightness: -icon.shade }

        AppIcon {
            anchors.fill: parent
            size: root.maxSize
            name: Dock.iconFor(root.key)
        }
    }

    // Running indicators: one dot per window (max 3); the focused app gets a pill.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height + 4
        spacing: 3
        opacity: root.dragging ? 0 : 1
        Repeater {
            model: Math.min(3, root.windows.length)
            Rectangle {
                required property int index
                width: root.focused && index === 0 ? 12 : 5
                height: 5
                radius: 2.5
                color: root.focused ? Theme.primary : Theme.alpha(Theme.surfaceFg, 0.7)
                Behavior on width { Anim { duration: Motion.duration.short } }
                Behavior on color { ColorAnim {} }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.bottomMargin: -12   // include the indicator strip
        hoverEnabled: true
        preventStealing: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onEntered: root.entered()
        onExited: root.exited()
        onPressed: m => {
            root.moved = false;
            root.pressPos = mapToItem(null, m.x, m.y);
        }
        onPositionChanged: m => {
            if (!(pressedButtons & Qt.LeftButton)) return;
            const p = mapToItem(null, m.x, m.y);
            if (!root.moved) {
                if (Math.hypot(p.x - root.pressPos.x, p.y - root.pressPos.y) < 8) return;
                root.moved = true;
                root.dragStarted(p);
            }
            root.dragMoved(p);
        }
        onReleased: m => {
            if (root.moved) root.dragFinished(mapToItem(null, m.x, m.y));
        }
        onCanceled: if (root.moved) root.dragFinished(Qt.point(-1, -1))
        onClicked: m => {
            if (root.moved) return;
            if (m.button === Qt.RightButton) root.contextRequested();
            else if (m.button === Qt.MiddleButton) root.middleClicked();
            else root.activated();
        }
        onPressAndHold: if (!root.moved) root.contextRequested()
    }
}
