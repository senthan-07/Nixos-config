pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

// Turns the default Bluetooth adapter on/off. BlueZ refuses to power an
// adapter that rfkill has soft-blocked (e.g. airplane mode or a state
// restored at boot), so clear the block first when switching on.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool blocked: adapter?.state === BluetoothAdapterState.Blocked

    function set(on) {
        if (!adapter) return;
        if (on && blocked) {
            unblock.running = true;     // powers on once rfkill has cleared
        } else {
            adapter.enabled = on;
        }
    }

    function toggle() {
        if (adapter) set(!adapter.enabled);
    }

    Process {
        id: unblock
        command: ["rfkill", "unblock", "bluetooth"]
        onExited: code => {
            if (code !== 0) console.warn("rice: rfkill unblock bluetooth failed");
            powerOn.restart();
        }
    }

    // BlueZ needs a moment to see the adapter as unblocked.
    Timer {
        id: powerOn
        interval: 600
        onTriggered: if (root.adapter) root.adapter.enabled = true
    }
}
