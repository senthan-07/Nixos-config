import QtQuick
import Quickshell.Hyprland

// HyprlandFocusGrab that arms a moment after `want` turns on.
// Hyprland drops a grab started in the same frame the surface changes its
// keyboard focus / input mask, emitting `cleared` straight away, which made
// panels close the instant they opened. `cleared` fires only for real
// outside clicks once armed.
Item {
    id: root

    property bool want: false
    property var windows: []
    signal cleared()

    property bool armed: false
    onWantChanged: {
        armed = false;
        if (want) delay.restart();
        else delay.stop();
    }

    Timer {
        id: delay
        interval: 150
        onTriggered: root.armed = root.want
    }

    HyprlandFocusGrab {
        windows: root.windows
        active: root.armed
        onCleared: {
            root.armed = false;
            root.cleared();
        }
    }
}
