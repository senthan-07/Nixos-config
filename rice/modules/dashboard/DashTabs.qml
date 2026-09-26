import QtQuick
import qs.config
import qs.components

// Pill-shaped tab bar with an elastic indicator: the leading edge moves
// first and the trailing edge catches up, so the pill stretches between tabs.
Rectangle {
    id: root

    readonly property var tabs: [
        { id: "weather", icon: "partly_cloudy_day", label: "Weather" },
        { id: "info", icon: "person", label: "Info" },
        { id: "drawer", icon: "apps", label: "Drawer" }
    ]
    readonly property int current: Math.max(0, tabs.findIndex(t => t.id === DashboardState.view))
    readonly property real pad: Tokens.space.xs
    readonly property real tabWidth: (width - pad * 2) / tabs.length
    readonly property real targetLeft: pad + current * tabWidth
    readonly property real targetRight: targetLeft + tabWidth

    // Which edge leads depends on the direction of travel.
    property bool movingRight: true
    property real edgeL: targetLeft
    property real edgeR: targetRight
    onCurrentChanged: movingRight = targetLeft > edgeL

    Behavior on edgeL { Anim { duration: root.movingRight ? Motion.duration.medium : Motion.duration.short; easing.bezierCurve: Motion.curve.emphasizedDecel } }
    Behavior on edgeR { Anim { duration: root.movingRight ? Motion.duration.short : Motion.duration.medium; easing.bezierCurve: Motion.curve.emphasizedDecel } }

    implicitHeight: 52
    radius: height / 2
    color: Theme.surfaceContainer

    Rectangle {
        x: root.edgeL
        y: root.pad
        width: root.edgeR - root.edgeL
        height: parent.height - root.pad * 2
        radius: height / 2
        color: Theme.secondaryContainer
    }

    Row {
        x: root.pad
        y: root.pad
        height: parent.height - root.pad * 2

        Repeater {
            model: root.tabs

            Surface {
                id: tab
                required property var modelData
                required property int index
                readonly property bool active: index === root.current

                width: root.tabWidth
                height: parent.height
                radius: height / 2
                interactive: true
                base: Theme.alpha(Theme.surfaceContainer, 0)
                content: Theme.surfaceFg
                color: hovered && !active ? Theme.alpha(Theme.surfaceFg, pressed ? 0.12 : 0.06) : "transparent"
                onClicked: DashboardState.setView(modelData.id)

                Row {
                    anchors.centerIn: parent
                    spacing: Tokens.space.s

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tab.modelData.icon
                        size: 20
                        fill: tab.active ? 1 : 0
                        color: tab.active ? Theme.secondaryContainerFg : Theme.surfaceVariantFg
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tab.modelData.label
                        font.weight: tab.active ? Font.DemiBold : Font.Medium
                        color: tab.active ? Theme.secondaryContainerFg : Theme.surfaceVariantFg
                    }
                }
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => DashboardState.cycle(event.angleDelta.y < 0 || event.angleDelta.x < 0 ? 1 : -1)
    }
}
