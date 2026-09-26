pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Global UI state for the overlay surfaces plus the `qs -c rice ipc` interface.
Singleton {
    id: root

    readonly property bool ready: true

    property bool launcher: false
    property bool sidebar: false
    property bool power: false
    property bool locked: false
    property bool caffeine: false
    // Settings app window (modules/settings) and the page it shows.
    property bool settings: false
    property string settingsPage: "General"

    function openSettings(page) {
        closeAll();
        if (page) settingsPage = page;
        settings = true;
    }

    // Close overlays, then run `fn` once they have animated away (used by
    // screen capture so panels are not in the frozen frame).
    function afterClose(fn) {
        closeAll();
        deferTimer.fn = fn;
        deferTimer.restart();
    }

    property Timer deferTimer: Timer {
        property var fn: null
        interval: 300
        onTriggered: if (fn) fn()
    }
    // Text pre-filled into the launcher the next time it opens.
    property string launcherQuery: ""

    function openLauncher(query) {
        closeAll();
        launcherQuery = query || "";
        launcher = true;
    }

    function closeAll() {
        launcher = false;
        sidebar = false;
        power = false;
    }

    // Focus grabs close a panel on outside clicks; if that click landed on the
    // panel's own bar button, don't immediately reopen it.
    property var closedAt: ({})
    function dismiss(name) {
        root[name] = false;
        const c = Object.assign({}, closedAt);
        c[name] = Date.now();
        closedAt = c;
    }

    function toggle(name) {
        if (!root[name] && Date.now() - (closedAt[name] || 0) < 250) return;
        const next = !root[name];
        closeAll();
        root[name] = next;
    }

    function run(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle("launcher"); }
        function open(): void { root.openLauncher(""); }
        function wallpapers(): void { root.openLauncher(":"); }
        function close(): void { root.launcher = false; }
    }

    IpcHandler {
        target: "sidebar"
        function toggle(): void { root.toggle("sidebar"); }
    }

    IpcHandler {
        target: "power"
        function toggle(): void { root.toggle("power"); }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.closeAll(); root.locked = true; }
        function isLocked(): bool { return root.locked; }
    }

    IpcHandler {
        target: "theme"
        function toggleDark(): void { Settings.data.darkMode = !Settings.data.darkMode; }
        function scheme(name: string): void { Settings.data.scheme = name; Wallpapers.regenerate(); }
    }

    IpcHandler {
        target: "shell"
        function reload(): void { Quickshell.reload(false); }
    }

    IpcHandler {
        target: "caffeine"
        function toggle(): void { root.caffeine = !root.caffeine; }
    }
}
