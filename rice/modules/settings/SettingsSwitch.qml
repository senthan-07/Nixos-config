import QtQuick
import qs.config
import qs.components

// M3 switch. Bind `checked`, react to `toggled()`.
Rectangle {
    id: root

    property bool checked
    signal toggled()

    implicitWidth: 52
    implicitHeight: 32
    radius: height / 2
    color: checked ? Theme.primary : Theme.surfaceHighest
    border.width: checked ? 0 : 2
    border.color: Theme.outline
    Behavior on color { ColorAnim {} }

    Rectangle {
        property int d: root.checked ? 24 : 16
        width: d
        height: d
        radius: d / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - d - 4 : 8
        color: root.checked ? Theme.primaryFg : Theme.outline
        Behavior on x { Anim { duration: Motion.duration.short; easing.bezierCurve: Motion.curve.springFast } }
        Behavior on d { Anim { duration: Motion.duration.short } }

        Icon {
            anchors.centerIn: parent
            visible: root.checked
            text: "check"
            size: 16
            color: Theme.primary
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
