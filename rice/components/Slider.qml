import QtQuick
import qs.config

// M3 expressive slider: thick track with an inset icon and a thin handle.
Item {
    id: root

    property real value: 0          // 0..1
    property string icon
    property color accent: Theme.primary
    property color onAccent: Theme.primaryFg
    signal moved(real value)

    implicitHeight: 40
    implicitWidth: 200

    readonly property real visual: drag.pressed ? drag.live : value
    readonly property real handleX: Math.max(0, Math.min(width - 4, visual * width - 2))

    Rectangle {
        id: active
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        width: Math.max(height, root.handleX - 4)
        radius: height / 2
        color: root.accent
        Behavior on width { enabled: !drag.pressed; Anim { duration: Motion.duration.short } }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height * 0.7
        width: Math.max(0, parent.width - root.handleX - 6)
        radius: height / 2
        color: Theme.surfaceHighest
    }

    Rectangle {
        x: root.handleX
        anchors.verticalCenter: parent.verticalCenter
        width: 4
        height: parent.height + 8
        radius: 2
        color: root.accent
        Behavior on x { enabled: !drag.pressed; Anim { duration: Motion.duration.short } }
    }

    Icon {
        anchors.left: parent.left
        anchors.leftMargin: (root.height - size) / 2
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        size: 20
        fill: 1
        color: root.onAccent
        visible: root.icon !== ""
    }

    MouseArea {
        id: drag
        property real live: 0
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        function update(x) {
            live = Math.max(0, Math.min(1, (x - 4) / root.width));
            root.moved(live);
        }
        onPressed: m => update(m.x)
        onPositionChanged: m => { if (pressed) update(m.x); }
        onWheel: w => root.moved(Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
