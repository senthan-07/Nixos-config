import QtQuick
import Quickshell
import Quickshell.Widgets

// Themed application icon with a Material glyph fallback.
Item {
    id: root

    property string name
    property real size: 32
    readonly property string source: name.startsWith("/") || name.startsWith("file:") || name.startsWith("image:")
        ? name : Quickshell.iconPath(name, true)

    implicitWidth: size
    implicitHeight: size

    IconImage {
        id: img
        anchors.centerIn: parent
        implicitSize: root.size
        source: root.source
        visible: root.source !== "" && status === Image.Ready
        asynchronous: true
    }

    Icon {
        anchors.centerIn: parent
        visible: !img.visible
        text: "apps"
        size: root.size * 0.8
    }
}
