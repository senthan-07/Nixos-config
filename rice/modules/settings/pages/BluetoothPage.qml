import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.modules.settings
import "../controls"
import qs.components
import qs.services
import qs.config

// Bluetooth: adapter power/visibility, paired devices (connect, trust, forget, battery)
// and discovery of new devices to pair.
SettingsPage {
    id: root

    property string selected: ""          // address of the expanded device row
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter?.enabled ?? false
    readonly property bool blocked: adapter?.state === BluetoothAdapterState.Blocked
    readonly property bool busyPower: adapter?.state === BluetoothAdapterState.Enabling || adapter?.state === BluetoothAdapterState.Disabling
    readonly property var all: adapter ? [...adapter.devices.values] : []
    readonly property var paired: all.filter(d => d.paired || d.bonded)
        .sort((a, b) => (b.connected - a.connected) || deviceName(a).localeCompare(deviceName(b)))
    readonly property var available: all.filter(d => !d.paired && !d.bonded && (d.name || d.deviceName))
        .sort((a, b) => deviceName(a).localeCompare(deviceName(b)))
    readonly property int connectedCount: paired.filter(d => d.connected).length

    function deviceName(d) { return d.name || d.deviceName || d.address; }
    function kindIcon(d) {
        const k = (d.icon || "").toLowerCase();
        return k.includes("headset") || k.includes("headphone") ? "headphones"
            : k.includes("audio") || k.includes("speaker") ? "speaker"
            : k.includes("phone") ? "smartphone"
            : k.includes("computer") ? "computer"
            : k.includes("mouse") ? "mouse"
            : k.includes("keyboard") ? "keyboard"
            : k.includes("gaming") || k.includes("joystick") ? "sports_esports"
            : k.includes("watch") ? "watch"
            : k.includes("tablet") ? "tablet"
            : k.includes("camera") ? "photo_camera"
            : k.includes("printer") ? "print"
            : "bluetooth";
    }
    function stateText(d) {
        if (d.pairing) return "Pairing…";
        if (d.state === BluetoothDeviceState.Connecting) return "Connecting…";
        if (d.state === BluetoothDeviceState.Disconnecting) return "Disconnecting…";
        if (d.connected) return "Connected";
        return d.paired ? "Not connected" : "Available";
    }
    function busy(d) {
        return d.pairing || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting;
    }
    function setPower(on) {
        if (adapter && Exec.allow(`bluetooth power ${on}`)) BluetoothPower.set(on);
    }
    function setDiscovering(on) {
        if (adapter && powered && adapter.discovering !== on && Exec.allow(`bluetooth discovering ${on}`)) adapter.discovering = on;
    }

    title: "Bluetooth"
    subtitle: "Connect headphones, keyboards, controllers and phones"

    Component.onCompleted: setDiscovering(true)
    Component.onDestruction: setDiscovering(false)
    onPoweredChanged: if (powered) setDiscovering(true)

    Banner {
        visible: root.blocked
        tone: "warning"
        text: "Bluetooth is blocked by a hardware switch or rfkill (e.g. airplane mode)."
    }

    // ---- hero ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: hero.implicitHeight + Tokens.space.xl * 2
        radius: Tokens.radius.xl
        color: root.powered ? Theme.primaryContainer : Theme.surfaceContainer
        Behavior on color { ColorAnim {} }

        RowLayout {
            id: hero
            anchors.fill: parent
            anchors.margins: Tokens.space.xl
            spacing: Tokens.space.xl

            Rectangle {
                implicitWidth: 72
                implicitHeight: 72
                radius: root.powered ? 24 : 36
                color: root.powered ? Theme.primary : Theme.surfaceHighest
                Behavior on radius { Anim { easing.bezierCurve: Motion.curve.springDefault } }
                Icon {
                    anchors.centerIn: parent
                    text: !root.adapter ? "bluetooth_disabled" : root.connectedCount > 0 ? "bluetooth_connected"
                        : root.powered ? "bluetooth" : "bluetooth_disabled"
                    size: 36
                    fill: 1
                    color: root.powered ? Theme.primaryFg : Theme.surfaceVariantFg
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                StyledText {
                    Layout.fillWidth: true
                    text: !root.adapter ? "No Bluetooth adapter" : root.adapter.name || root.adapter.adapterId
                    font.pixelSize: Tokens.font.xxl
                    font.weight: Font.DemiBold
                    color: root.powered ? Theme.primaryContainerFg : Theme.surfaceFg
                }
                StyledText {
                    Layout.fillWidth: true
                    text: !root.adapter ? "Plug in a Bluetooth dongle or enable the adapter in firmware"
                        : root.busyPower ? "Switching…"
                        : !root.powered ? "Off"
                        : root.connectedCount > 0 ? `${root.connectedCount} device${root.connectedCount > 1 ? "s" : ""} connected`
                        : root.adapter.discoverable ? "On · visible to nearby devices" : "On"
                    color: root.powered ? Theme.alpha(Theme.primaryContainerFg, 0.8) : Theme.surfaceVariantFg
                }
            }
            Spinner { visible: root.busyPower; size: 28; color: root.powered ? Theme.primaryContainerFg : Theme.primary }
            SettingsSwitch {
                visible: root.adapter !== null
                checked: root.powered
                onToggled: root.setPower(!root.powered)
            }
        }
    }

    EmptyState {
        visible: !root.adapter
        icon: "bluetooth_disabled"
        title: "Bluetooth unavailable"
        text: "BlueZ didn't report an adapter. Check that the bluetooth service is running."
    }

    SettingsSection {
        title: "Adapter"
        visible: root.adapter !== null && root.powered

        SettingsRow {
            icon: "visibility"
            label: "Visible to nearby devices"
            description: root.adapter?.discoverable ? `Shown as "${root.adapter?.name ?? ""}"` : "Other devices can't find this computer"
            SettingsSwitch {
                checked: root.adapter?.discoverable ?? false
                onToggled: if (Exec.allow("bluetooth discoverable")) root.adapter.discoverable = !root.adapter.discoverable
            }
        }
        SettingsRow {
            icon: "link"
            label: "Allow pairing"
            description: "Accept pairing requests from other devices"
            SettingsSwitch {
                checked: root.adapter?.pairable ?? false
                onToggled: if (Exec.allow("bluetooth pairable")) root.adapter.pairable = !root.adapter.pairable
            }
        }
    }

    // ---- paired ----
    SettingsSection {
        title: "My devices"
        visible: root.adapter !== null && root.powered

        EmptyState {
            visible: root.paired.length === 0
            icon: "devices_other"
            title: "No paired devices"
            text: "Put a device in pairing mode and pick it from the list below."
        }

        Repeater {
            model: root.paired

            ListRow {
                id: dev
                required property var modelData
                readonly property var d: modelData

                icon: root.kindIcon(d)
                highlighted: d.connected
                interactive: true
                chevron: true
                busy: root.busy(d)
                expanded: root.selected === d.address
                title: root.deviceName(d)
                subtitle: root.stateText(d)
                onClicked: root.selected = root.selected === d.address ? "" : d.address

                // Battery pill
                Rectangle {
                    visible: dev.d.batteryAvailable
                    implicitWidth: batRow.implicitWidth + Tokens.space.m * 2
                    implicitHeight: 28
                    radius: 14
                    color: dev.d.battery < 0.2 ? Theme.errorContainer : dev.highlighted ? Theme.primary : Theme.surfaceHighest
                    RowLayout {
                        id: batRow
                        anchors.centerIn: parent
                        spacing: 2
                        Icon {
                            readonly property real b: dev.d.battery
                            text: b > 0.9 ? "battery_full" : b > 0.7 ? "battery_6_bar" : b > 0.5 ? "battery_5_bar"
                                : b > 0.35 ? "battery_4_bar" : b > 0.2 ? "battery_2_bar" : "battery_alert"
                            size: 16
                            rotation: 90
                            color: dev.d.battery < 0.2 ? Theme.errorContainerFg : dev.highlighted ? Theme.primaryFg : Theme.surfaceFg
                        }
                        StyledText {
                            text: `${Math.round(dev.d.battery * 100)}%`
                            font.pixelSize: Tokens.font.s
                            font.weight: Font.DemiBold
                            color: dev.d.battery < 0.2 ? Theme.errorContainerFg : dev.highlighted ? Theme.primaryFg : Theme.surfaceFg
                        }
                    }
                }

                expansion: [
                    RowLayout {
                        spacing: Tokens.space.s
                        ActionButton {
                            text: dev.d.connected ? "Disconnect" : "Connect"
                            icon: dev.d.connected ? "link_off" : "link"
                            kind: dev.d.connected ? "outlined" : "filled"
                            busy: dev.busy
                            onClicked: {
                                if (!Exec.allow(`bluetooth ${dev.d.connected ? "disconnect" : "connect"} ${dev.d.address}`)) return;
                                if (dev.d.connected) dev.d.disconnect(); else dev.d.connect();
                            }
                        }
                        ActionButton {
                            text: "Forget"
                            icon: "delete"
                            onClicked: { forgetDialog.target = dev.d; forgetDialog.open(); }
                        }
                    },
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.space.m
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            StyledText { text: "Trusted"; font.weight: Font.Medium }
                            StyledText {
                                Layout.fillWidth: true
                                text: "Connect automatically without asking"
                                font.pixelSize: Tokens.font.s
                                color: Theme.surfaceVariantFg
                            }
                        }
                        SettingsSwitch {
                            checked: dev.d.trusted
                            onToggled: if (Exec.allow(`bluetooth trust ${dev.d.address}`)) dev.d.trusted = !dev.d.trusted
                        }
                    },
                    RowLayout {
                        Layout.fillWidth: true
                        visible: dev.d.batteryAvailable
                        spacing: Tokens.space.m
                        StyledText { text: "Battery"; font.weight: Font.Medium }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 8
                            radius: 4
                            color: Theme.surfaceHighest
                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, dev.d.battery))
                                height: parent.height
                                radius: 4
                                color: dev.d.battery < 0.2 ? Theme.error : Theme.primary
                                Behavior on width { Anim {} }
                            }
                        }
                        StyledText { text: `${Math.round(dev.d.battery * 100)}%`; color: Theme.surfaceVariantFg }
                    },
                    StyledText {
                        Layout.fillWidth: true
                        text: `${dev.d.address}${dev.d.icon ? "  ·  " + dev.d.icon : ""}`
                        font.family: Tokens.font.mono
                        font.pixelSize: Tokens.font.s
                        color: Theme.surfaceVariantFg
                    }
                ]
            }
        }
    }

    // ---- discovery ----
    SettingsSection {
        title: "Available devices"
        visible: root.adapter !== null && root.powered

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Tokens.space.m
            spacing: Tokens.space.m
            Spinner { visible: root.adapter?.discovering ?? false; size: 20 }
            StyledText {
                Layout.fillWidth: true
                text: root.adapter?.discovering ? "Searching for devices…" : "Not searching"
                color: Theme.surfaceVariantFg
            }
            ActionButton {
                text: root.adapter?.discovering ? "Stop" : "Search"
                icon: root.adapter?.discovering ? "stop" : "radar"
                kind: "tonal"
                onClicked: root.setDiscovering(!root.adapter.discovering)
            }
        }

        Repeater {
            model: root.available

            ListRow {
                id: nd
                required property var modelData
                readonly property var d: modelData
                icon: root.kindIcon(d)
                interactive: !d.pairing
                busy: d.pairing
                title: root.deviceName(d)
                subtitle: d.pairing ? "Pairing… confirm on the device if asked" : "Tap to pair"
                onClicked: if (Exec.allow(`bluetooth pair ${d.address}`)) d.pair()
                ActionButton {
                    visible: nd.d.pairing
                    text: "Cancel"
                    onClicked: if (Exec.allow(`bluetooth cancel pair ${nd.d.address}`)) nd.d.cancelPair()
                }
                ActionButton {
                    visible: !nd.d.pairing
                    text: "Pair"
                    kind: "tonal"
                    onClicked: nd.clicked(null)
                }
            }
        }

        EmptyState {
            visible: root.available.length === 0
            loading: root.adapter?.discovering ?? false
            icon: "bluetooth_searching"
            title: root.adapter?.discovering ? "Looking for nearby devices…" : "No new devices"
            text: root.adapter?.discovering ? "" : "Start a search and put your device in pairing mode."
        }
    }

    Dialog {
        id: forgetDialog
        property var target: null
        icon: "bluetooth_disabled"
        title: `Forget ${target ? root.deviceName(target) : ""}?`
        text: "The device will be unpaired. You'll need to pair it again to use it."
        confirmText: "Forget"
        danger: true
        onConfirmed: {
            if (target && Exec.allow(`bluetooth forget ${target.address}`)) target.forget();
            root.selected = "";
        }
    }
}
