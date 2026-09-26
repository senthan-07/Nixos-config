import QtQuick
import QtQuick.Layouts
import qs.config

// Quick-settings toggle tile: icon, label and optional sub-label.
Surface {
    id: root

    property string icon
    property string label
    property string sublabel
    property bool active: false

    signal toggled()
    signal secondary()

    implicitHeight: 64
    interactive: true
    radius: active ? Tokens.radius.l : Tokens.radius.xl
    base: active ? Theme.primary : Theme.surfaceHigh
    content: active ? Theme.primaryFg : Theme.surfaceFg
    onClicked: m => m.button === Qt.RightButton ? root.secondary() : root.toggled()

    Behavior on radius { Anim { duration: Motion.duration.short } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.space.l
        anchors.rightMargin: Tokens.space.l
        spacing: Tokens.space.m

        Icon {
            text: root.icon
            size: 24
            fill: root.active ? 1 : 0
            color: root.content
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            StyledText {
                Layout.fillWidth: true
                text: root.label
                font.weight: Font.DemiBold
                color: root.content
            }
            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.sublabel
                font.pixelSize: Tokens.font.s
                color: Theme.alpha(root.content, 0.8)
            }
        }
    }
}
