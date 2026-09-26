import QtQuick
import qs.config
import qs.components

// Tonal circle holding a Material symbol (leading visual for list rows).
Rectangle {
    id: root

    property string icon
    property bool active: false
    property real size: 40
    property color tint: active ? Theme.primary : Theme.surfaceHighest
    property color glyph: active ? Theme.primaryFg : Theme.surfaceVariantFg

    implicitWidth: size
    implicitHeight: size
    radius: active ? size * 0.32 : size / 2
    color: tint
    Behavior on radius { Anim { duration: Motion.duration.short; easing.bezierCurve: Motion.curve.springFast } }
    Behavior on color { ColorAnim {} }

    Icon {
        anchors.centerIn: parent
        text: root.icon
        size: root.size * 0.5
        fill: root.active ? 1 : 0
        color: root.glyph
    }
}
