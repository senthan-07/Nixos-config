import QtQuick
import qs.config

// Circular (or squircle when toggled) icon button following M3 "standard" / "filled" styles.
Surface {
    id: root

    property string icon
    property real iconSize: 20
    property bool toggled: false
    property bool filled: false
    property int size: 36

    implicitWidth: size
    implicitHeight: size
    interactive: true
    radius: toggled ? Tokens.radius.m : size / 2
    base: toggled ? Theme.primary : filled ? Theme.surfaceHighest : Theme.alpha(Theme.surface, 0)
    content: toggled ? Theme.primaryFg : Theme.surfaceVariantFg

    Behavior on radius { Anim { duration: Motion.duration.short } }

    Icon {
        anchors.centerIn: parent
        text: root.icon
        size: root.iconSize
        fill: root.toggled ? 1 : 0
        color: root.content
    }
}
