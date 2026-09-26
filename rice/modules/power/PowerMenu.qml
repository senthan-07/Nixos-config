import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

PanelWindow {
    id: root

    readonly property var actions: [
        { icon: "lock", label: "Lock", run: () => { Panels.locked = true; } },
        { icon: "bedtime", label: "Suspend", run: () => { Panels.locked = true; Quickshell.execDetached(["systemctl", "suspend"]); } },
        { icon: "logout", label: "Log out", run: () => Hypr.exit() },
        { icon: "restart_alt", label: "Restart", run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
        { icon: "power_settings_new", label: "Shut down", run: () => Quickshell.execDetached(["systemctl", "poweroff"]) }
    ]
    property int selected: 0

    screen: Quickshell.screens[0]
    visible: Panels.power || scrim.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "rice-power"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Panels.power ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: if (visible) { selected = 0; row.forceActiveFocus(); }

    function trigger(i) {
        Panels.power = false;
        actions[i].run();
    }

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Theme.alpha(Theme.scrim, 0.55)
        opacity: Panels.power ? 1 : 0
        Behavior on opacity { Anim { duration: Motion.duration.short } }
        MouseArea { anchors.fill: parent; onClicked: Panels.power = false }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Tokens.space.xl
        opacity: scrim.opacity
        scale: 0.9 + 0.1 * scrim.opacity

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: `Goodbye, ${Quickshell.env("USER")}`
            font.pixelSize: Tokens.font.xxl + 8
            font.weight: Font.DemiBold
            color: "white"
        }

        RowLayout {
            id: row
            spacing: Tokens.space.l
            focus: true

            Keys.onEscapePressed: Panels.power = false
            Keys.onLeftPressed: root.selected = (root.selected + root.actions.length - 1) % root.actions.length
            Keys.onRightPressed: root.selected = (root.selected + 1) % root.actions.length
            Keys.onTabPressed: root.selected = (root.selected + 1) % root.actions.length
            Keys.onReturnPressed: root.trigger(root.selected)
            Keys.onEnterPressed: root.trigger(root.selected)

            Repeater {
                model: root.actions

                ColumnLayout {
                    id: action
                    required property var modelData
                    required property int index
                    readonly property bool current: root.selected === index
                    spacing: Tokens.space.s

                    Surface {
                        implicitWidth: 96
                        implicitHeight: 96
                        radius: action.current ? Tokens.radius.xl : 48
                        interactive: true
                        base: action.current ? (action.index === 4 ? Theme.error : Theme.primary) : Theme.surfaceHigh
                        content: action.current ? (action.index === 4 ? Theme.errorFg : Theme.primaryFg) : Theme.surfaceFg
                        onClicked: root.trigger(action.index)
                        onHoveredChanged: if (hovered) root.selected = action.index
                        Behavior on radius { Anim { duration: Motion.duration.short; easing.bezierCurve: Motion.curve.springDefault } }

                        Icon {
                            anchors.centerIn: parent
                            text: action.modelData.icon
                            size: 36
                            fill: action.current ? 1 : 0
                            color: parent.content
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: action.modelData.label
                        color: "white"
                        font.weight: action.current ? Font.Bold : Font.Normal
                    }
                }
            }
        }
    }
}
