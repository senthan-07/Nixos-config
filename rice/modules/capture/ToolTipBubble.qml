import QtQuick
import qs.config
import qs.components

// Small inverse-surface label that floats above its parent on hover.
Rectangle {
    id: root

    property bool shown: false
    property alias text: label.text

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.top
    anchors.bottomMargin: Tokens.space.s + (shown ? 4 : 0)
    width: label.implicitWidth + Tokens.space.m * 2
    height: 28
    radius: Tokens.radius.s
    color: Theme.inverseSurface
    opacity: shown ? 1 : 0
    visible: opacity > 0
    z: 10

    Behavior on opacity { Anim { duration: Motion.duration.short } }
    Behavior on anchors.bottomMargin { Anim { duration: Motion.duration.short } }

    StyledText {
        id: label
        anchors.centerIn: parent
        font.pixelSize: Tokens.font.s
        color: Theme.inverseOnSurface
    }
}
