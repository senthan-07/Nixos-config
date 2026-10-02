pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs.components

// Turns the default Bluetooth adapter on/off. BlueZ refuses to power an
// adapter that rfkill has soft-blocked (e.g. airplane mode or a state
// restored at boot), so clear the block first when switching on.
// The chosen state is saved ($XDG_STATE_HOME/rice/bluetooth.json) and applied
// again at login: NixOS powers the adapter on at every boot by default.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool blocked: adapter?.state === BluetoothAdapterState.Blocked

    function set(on) {
        if (!adapter) return;
        store.set("enabled", !!on);
        if (on && blocked) {
            unblock.running = true;     // powers on once rfkill has cleared
        } else {
            adapter.enabled = on;
        }
    }

    function toggle() {
        if (adapter) set(!adapter.enabled);
    }

    JsonStore { id: store; name: "bluetooth" }

    // Restore the saved state once, when both the file and the adapter exist.
    // Nothing saved yet (never toggled from rice) leaves the adapter alone.
    property bool restored: false
    readonly property bool canRestore: store.ready && !!adapter
    onCanRestoreChanged: restore()
    Component.onCompleted: restore()
    function restore() {
        if (restored || !canRestore) return;
        restored = true;
        const want = store.get("enabled", null);
        if (want === null || want === adapter.enabled) return;
        console.info(`rice: restoring bluetooth ${want ? "on" : "off"}`);
        if (want && blocked) unblock.running = true;
        else adapter.enabled = want;
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
