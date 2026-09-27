pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.services

// Open state, active tab and IPC for the left dashboard.
//   qs -c rice ipc call dashboard toggle | open | close
//   qs -c rice ipc call dashboard openTab weather|info
Singleton {
    id: root

    readonly property var views: ["weather", "info"]

    property bool open: false
    // (a stored "drawer" from before the drawer was removed falls back to weather)
    property string view: views.indexOf(store.get("view", "")) >= 0 ? store.get("view", "") : "weather"
    property real closedAt: 0

    function setView(name) {
        if (views.indexOf(name) < 0 || name === view) return;
        view = name;
        store.set("view", name);
    }

    function cycle(delta) {
        const i = views.indexOf(view);
        setView(views[(i + delta + views.length) % views.length]);
    }

    function show(name) {
        if (name) setView(name);
        if (!open) {
            // Share the screen politely with the other overlays.
            Panels.launcher = false;
            Panels.sidebar = false;
            Panels.power = false;
            open = true;
        }
    }

    function close() {
        open = false;
    }

    // Called by the focus grab: remember when, so the click that dismissed the
    // panel does not immediately reopen it through the bar chip.
    function dismiss() {
        open = false;
        closedAt = Date.now();
    }

    function toggle() {
        if (open) close();
        else if (Date.now() - closedAt > 250) show("");
    }

    Connections {
        target: Panels
        function onLauncherChanged() { if (Panels.launcher) root.open = false; }
        function onSidebarChanged() { if (Panels.sidebar) root.open = false; }
        function onPowerChanged() { if (Panels.power) root.open = false; }
        function onLockedChanged() { if (Panels.locked) root.open = false; }
    }

    JsonStore {
        id: store
        name: "dashboard"
    }

    IpcHandler {
        target: "dashboard"
        function toggle(): void { root.toggle(); }
        function open(): void { root.show(""); }
        function close(): void { root.close(); }
        function openTab(name: string): void { root.show(name); }
        function isOpen(): bool { return root.open; }
        function current(): string { return root.view; }
    }
}
