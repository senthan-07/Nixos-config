import QtQuick

// A soft cartoon cloud built from overlapping circles on a rounded base.
// Size it with width; height follows at roughly half the width.
Item {
    id: root

    property color color: "white"

    implicitWidth: 160
    implicitHeight: width * 0.46

    // Slight darker underside gives the cloud some volume.
    Rectangle {
        x: root.width * 0.06
        y: root.height * 0.52
        width: root.width * 0.88
        height: root.height * 0.48
        radius: height / 2
        color: Qt.darker(root.color, 1.08)
    }
    Rectangle {
        x: root.width * 0.14
        y: root.height * 0.30
        width: root.width * 0.36
        height: width
        radius: width / 2
        color: root.color
    }
    Rectangle {
        x: root.width * 0.34
        y: 0
        width: root.width * 0.42
        height: width
        radius: width / 2
        color: root.color
    }
    Rectangle {
        x: root.width * 0.60
        y: root.height * 0.26
        width: root.width * 0.30
        height: width
        radius: width / 2
        color: root.color
    }
    Rectangle {
        x: root.width * 0.04
        y: root.height * 0.50
        width: root.width * 0.92
        height: root.height * 0.42
        radius: height / 2
        color: root.color
    }
}
