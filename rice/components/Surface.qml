import QtQuick
import qs.config

// Rounded container with M3 hover/press state layer and optional click handling.
Rectangle {
    id: root

    property color base: Theme.surfaceContainer
    property color content: Theme.surfaceFg
    property bool interactive: false
    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    signal clicked(var mouse)
    signal wheel(var wheel)

    radius: Tokens.radius.m
    color: interactive ? Theme.stateLayer(base, content, hovered, pressed) : base

    Behavior on color { ColorAnim {} }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => root.clicked(m)
        // Let scrollable parents see the wheel too (handlers still get it first).
        onWheel: w => { w.accepted = false; root.wheel(w); }
    }
}
