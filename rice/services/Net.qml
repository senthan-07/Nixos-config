pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: devices.find(d => d.type === DeviceType.Wired) ?? null
    readonly property bool wired: wiredDevice?.connected ?? false

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property var networks: wifiDevice ? [...wifiDevice.networks.values].sort((a, b) =>
        (b.connected - a.connected) || (b.signalStrength - a.signalStrength)) : []
    readonly property var active: networks.find(n => n.connected) ?? null
    readonly property real strength: active?.signalStrength ?? 0

    readonly property string label: wired ? "Ethernet" : active ? active.name : wifiEnabled ? "Disconnected" : "Wi-Fi off"
    readonly property string icon: wired ? "lan"
        : !wifiEnabled ? "wifi_off"
        : !active ? "wifi_find"
        : strength > 0.75 ? "network_wifi"
        : strength > 0.5 ? "network_wifi_3_bar"
        : strength > 0.25 ? "network_wifi_2_bar" : "network_wifi_1_bar"

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function setScanning(on) {
        if (wifiDevice) wifiDevice.scannerEnabled = on;
    }
}
