import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

RowLayout {
    id: root

    property string title
    property bool checked
    signal back()
    signal toggle()

    Layout.fillWidth: true
    Layout.bottomMargin: Tokens.space.s
    spacing: Tokens.space.s

    IconButton { icon: "arrow_back"; onClicked: root.back() }

    StyledText {
        Layout.fillWidth: true
        text: root.title
        font.pixelSize: Tokens.font.xl
        font.weight: Font.DemiBold
    }

    // M3 switch
    Rectangle {
        implicitWidth: 52
        implicitHeight: 32
        radius: height / 2
        color: root.checked ? Theme.primary : Theme.surfaceHighest
        border.width: root.checked ? 0 : 2
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
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggle()
        }
    }
}
