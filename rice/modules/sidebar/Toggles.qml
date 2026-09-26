import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services
import qs.modules.cards

GridLayout {
    id: root

    signal openPage(string name)

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var btConnected: adapter?.devices.values.filter(d => d.connected) ?? []

    Layout.fillWidth: true
    columns: 2
    rowSpacing: Tokens.space.s
    columnSpacing: Tokens.space.s

    Tile {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        icon: Net.icon
        label: "Wi-Fi"
        sublabel: Net.label
        active: Net.wifiEnabled || Net.wired
        onToggled: Net.toggleWifi()
        onSecondary: root.openPage("wifi")
    }
    Tile {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        icon: root.btConnected.length ? "bluetooth_connected" : root.adapter?.enabled ? "bluetooth" : "bluetooth_disabled"
        label: "Bluetooth"
        sublabel: !root.adapter ? "Unavailable" : !root.adapter.enabled ? "Off"
            : root.btConnected.length ? root.btConnected[0].name : "On"
        active: root.adapter?.enabled ?? false
        onToggled: BluetoothPower.toggle()
        onSecondary: root.openPage("bluetooth")
    }
    Tile {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        icon: Settings.data.darkMode ? "dark_mode" : "light_mode"
        label: "Dark mode"
        sublabel: Settings.data.darkMode ? "On" : "Off"
        active: Settings.data.darkMode
        onToggled: Settings.data.darkMode = !Settings.data.darkMode
        onSecondary: Panels.openSettings("Appearance")
    }
    // Power profile (power-profiles-daemon: CPU + HP platform profile).
    // Click cycles saver → balanced → performance; right-click picks one.
    Tile {
        id: perf
        readonly property var order: PowerProfiles.hasPerformanceProfile
            ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
            : [PowerProfile.PowerSaver, PowerProfile.Balanced]
        readonly property int current: PowerProfiles.profile
        function step(d) {
            const i = order.indexOf(current);
            PowerProfiles.profile = order[(i + d + order.length) % order.length];
        }

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        icon: current === PowerProfile.Performance ? "bolt"
            : current === PowerProfile.PowerSaver ? "eco" : "balance"
        label: "Performance"
        sublabel: current === PowerProfile.Performance ? "Performance"
            : current === PowerProfile.PowerSaver ? "Power saver" : "Balanced"
        active: current !== PowerProfile.Balanced
        onToggled: step(1)
        onSecondary: root.openPage("performance")
    }
    Tile {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        icon: Notifs.dnd ? "do_not_disturb_on" : "notifications"
        label: "Do not disturb"
        sublabel: Notifs.dnd ? "Silenced" : "Off"
        active: Notifs.dnd
        onToggled: Settings.data.doNotDisturb = !Settings.data.doNotDisturb
    }
    Tile {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        icon: "coffee"
        label: "Caffeine"
        sublabel: Panels.caffeine ? "Staying awake" : "Off"
        active: Panels.caffeine
        onToggled: Panels.caffeine = !Panels.caffeine
        onSecondary: Panels.openSettings("Idle")
    }
    Tile {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        icon: "nightlight"
        label: "Night light"
        sublabel: NightLight.active ? `${NightLight.temperature} K` : NightLight.scheduled ? `From ${NightLight.from}` : "Off"
        active: NightLight.enabled
        onToggled: NightLight.toggle()
        onSecondary: Panels.openSettings("NightLight")
    }
    Tile {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        icon: "dashboard_customize"
        label: "Desktop widgets"
        sublabel: DesktopCards.editing ? "Editing" : DesktopCards.enabled ? "On" : "Off"
        active: DesktopCards.enabled
        onToggled: DesktopCards.setEnabled(!DesktopCards.enabled)
        onSecondary: { Panels.closeAll(); DesktopCards.setEditing(true); }
    }

    // Quick actions
    RowLayout {
        Layout.columnSpan: 2
        Layout.fillWidth: true
        Layout.topMargin: Tokens.space.xs
        spacing: Tokens.space.xs

        component Action: IconButton {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            filled: true
            radius: Tokens.radius.l
        }

        Action { icon: "screenshot_region"; onClicked: Panels.afterClose(() => Capture.begin("screenshot", "region")) }
        Action { icon: "screen_record"; onClicked: Panels.afterClose(() => Capture.begin("record", "region")) }
        Action { icon: "colorize"; onClicked: Panels.afterClose(() => Capture.begin("pick", "region")) }
        Action { icon: "document_scanner"; onClicked: Panels.afterClose(() => Capture.begin("ocr", "region")) }
        Action { icon: "content_paste"; onClicked: Panels.openLauncher(";") }
        Action { icon: "mood"; onClicked: Panels.openLauncher(".") }
    }

    StyledText {
        Layout.columnSpan: 2
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: "Click to toggle · right-click for details"
        font.pixelSize: Tokens.font.xs
        color: Theme.outline
    }
}
