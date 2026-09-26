import QtQuick
import QtQuick.Effects
import qs.config
import qs.components
import qs.services

// The folder "stack" at the end of the dock: the newest files piled on top
// of each other, like a macOS stack. Clicking fans them out (DockFan).
Item {
    id: root

    property real size: 48
    property real maxSize: 96
    property bool open: false

    readonly property var newest: Dock.files.slice(0, 3)
    readonly property bool containsMouse: mouse.containsMouse
    signal entered()
    signal exited()
    signal activated()
    signal contextRequested()

    width: size
    height: size

    Item {
        id: art
        width: root.maxSize
        height: root.maxSize
        x: (root.width - width) / 2
        y: root.height - height
        transformOrigin: Item.Bottom
        scale: root.size / root.maxSize

        layer.enabled: mouse.pressed
        layer.effect: MultiEffect { brightness: -0.25 }

        // Base: a folder tile, always visible so an empty folder still reads well.
        Rectangle {
            anchors.fill: parent
            anchors.margins: parent.width * 0.06
            radius: width * 0.26
            color: Theme.primaryContainer
            opacity: root.newest.length ? 0.55 : 1
            Icon {
                anchors.centerIn: parent
                text: Dock.folderError ? "folder_off" : "download"
                size: parent.width * 0.5
                fill: 1
                color: Theme.primaryContainerFg
            }
        }

        // Newest files, slightly rotated. The newest sits on top.
        Repeater {
            model: root.newest.length
            DockFileGlyph {
                required property int index
                readonly property int depth: root.newest.length - 1 - index
                file: root.newest[depth]
                size: art.width * 0.72
                x: (art.width - width) / 2 + (depth - 1) * art.width * 0.05
                y: (art.height - height) / 2 - depth * art.width * 0.05
                rotation: root.open ? 0 : [-2, 5, -7][depth]
                opacity: root.open ? 0 : 1
                Behavior on rotation { Anim { duration: Motion.duration.short } }
                Behavior on opacity { Anim { duration: Motion.duration.short } }
            }
        }

        // Open state: a chevron, like closing the fan.
        Rectangle {
            anchors.fill: parent
            anchors.margins: parent.width * 0.06
            radius: width * 0.26
            color: Theme.surfaceHighest
            opacity: root.open ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { Anim { duration: Motion.duration.short } }
            Icon {
                anchors.centerIn: parent
                text: "expand_more"
                size: parent.width * 0.55
                color: Theme.surfaceFg
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.bottomMargin: -12
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: root.entered()
        onExited: root.exited()
        onClicked: m => m.button === Qt.RightButton ? root.contextRequested() : root.activated()
    }
}
