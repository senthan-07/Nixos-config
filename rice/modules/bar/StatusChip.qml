import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services

// Network / Bluetooth / audio / battery summary; opens the sidebar.
Chip {
    id: root

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isLaptopBattery ?? false
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging
        || battery?.state === UPowerDeviceState.FullyCharged
    readonly property real level: battery?.percentage ?? 0
    readonly property var adapter: Bluetooth.defaultAdapter

    interactive: true
    base: Panels.sidebar ? Theme.secondaryContainer : Theme.surfaceContainer
    onClicked: Panels.toggle("sidebar")
    onWheel: w => Audio.setVolume(Audio.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05))

    Icon { text: Net.icon; size: 17 }
    Icon {
        visible: root.adapter?.enabled ?? false
        text: root.adapter?.devices.values.some(d => d.connected) ? "bluetooth_connected" : "bluetooth"
        size: 17
    }
    Icon { text: Audio.icon; size: 17 }
    Icon {
        visible: Audio.micMuted
        text: "mic_off"
        size: 17
        color: Theme.error
    }
    Icon {
        visible: Notifs.dnd
        text: "do_not_disturb_on"
        size: 17
    }

    // Battery as a small horizontal gauge with the percentage inside.
    Rectangle {
        visible: root.hasBattery
        implicitWidth: 36
        implicitHeight: 18
        radius: 6
        color: Theme.surfaceHighest

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * root.level
            radius: parent.radius
            color: root.charging ? Theme.tertiary : root.level < 0.2 ? Theme.error : Theme.primary
            Behavior on width { Anim {} }
        }

        StyledText {
            anchors.centerIn: parent
            text: Math.round(root.level * 100)
            font.pixelSize: Tokens.font.xs
            font.weight: Font.Bold
            color: root.level > 0.5 ? (root.charging ? Theme.tertiaryFg : root.level < 0.2 ? Theme.errorFg : Theme.primaryFg) : Theme.surfaceFg
        }
    }
    Icon {
        visible: root.hasBattery && root.charging
        text: "bolt"
        size: 14
        fill: 1
        color: Theme.tertiary
    }
}
