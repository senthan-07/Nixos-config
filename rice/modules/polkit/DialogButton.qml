import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// M3 dialog action: "filled" or text style, with an optional busy spinner.
Surface {
    id: root

    property string text
    property string icon: ""
    property bool filled: false
    property bool busy: false
    property bool focused: activeFocus

    signal activated()

    implicitHeight: 40
    implicitWidth: Math.max(88, row.implicitWidth + Tokens.space.xl * 2)
    radius: height / 2
    interactive: enabled && !busy
    opacity: enabled ? 1 : 0.5
    base: filled ? Theme.primary : Theme.alpha(Theme.primary, 0)
    content: filled ? Theme.primaryFg : Theme.primary
    activeFocusOnTab: true
    border.width: focused ? 2 : 0
    border.color: filled ? Theme.primaryContainerFg : Theme.primary

    onClicked: if (!busy) root.activated()
    Keys.onReturnPressed: if (!busy) root.activated()
    Keys.onSpacePressed: if (!busy) root.activated()

    Behavior on implicitWidth { Anim { duration: Motion.duration.short } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.space.s

        Item {
            visible: root.busy || root.icon !== ""
            implicitWidth: 18
            implicitHeight: 18

            Icon {
                anchors.centerIn: parent
                visible: !root.busy
                text: root.icon
                size: 18
                color: root.content
            }

            Ring {
                id: spinner
                anchors.fill: parent
                visible: root.busy
                value: 0.7
                thickness: 2.5
                color: root.content
                track: "transparent"
                RotationAnimation on rotation {
                    running: spinner.visible
                    from: 0; to: 360
                    duration: 900
                    loops: Animation.Infinite
                }
            }
        }

        StyledText {
            text: root.text
            color: root.content
            font.pixelSize: Tokens.font.m + 1
            font.weight: Font.DemiBold
        }
    }
}
